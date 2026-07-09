import 'dart:async';
import 'dart:convert';
import '../../core/app_language.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import 'device_activation_wait_screen.dart';

/// Local Wi-Fi setup for a new or already-registered Easy Home Control switch.
///
/// The device contract is intentionally unchanged:
/// - Wi-Fi credentials go only to the local ESP hotspot at 192.168.4.1.
/// - The ESP saves them only after it has joined the selected home Wi-Fi.
/// - Recovery never changes pairing, ownership, timers, schedules, or relay data.
class WifiSetupScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  /// True for an already registered switch after a router, network, or Wi-Fi
  /// password change. It changes guidance only; ownership is never touched.
  final bool recoveryMode;

  const WifiSetupScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.recoveryMode = false,
  });

  /// Matches the firmware device-specific setup hotspot format.
  static String hotspotNameForDevice(String deviceId) {
    final clean = deviceId.trim().toUpperCase();
    final suffix = clean.length <= 5 ? clean : clean.substring(clean.length - 5);
    return 'EHC_SETUP_$suffix';
  }

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

enum _ProvisionStage {
  waitingForHotspot,
  readyForHomeWifi,
  testingHomeWifi,
  awaitingEspConfirmation,
  homeWifiRejected,
  homeWifiSaved,
}

class _WifiSetupScreenState extends State<WifiSetupScreen>
    with WidgetsBindingObserver {
  static final Uri _saveUri = Uri.parse('http://192.168.4.1/save');
  static final Uri _statusUri = Uri.parse('http://192.168.4.1/status');

  // The ESP can briefly stop answering its local hotspot while it changes
  // Wi-Fi channel and joins the submitted home network. Firmware may spend up
  // to 25 seconds testing credentials, then keeps the hotspot available long
  // enough to report the result. Never show a failure merely because a local
  // status request is temporarily unavailable during that window.
  static const Duration _homeWifiJoinGracePeriod = Duration(seconds: 40);

  final TextEditingController _wifiNameController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();

  Timer? _statusTimer;
  Timer? _hotspotDiscoveryTimer;
  bool _pollInFlight = false;
  bool _checkingHotspot = false;
  bool _hotspotVerified = false;
  bool _submitting = false;
  bool _hidePassword = true;
  int _statusFailures = 0;

  // Every submitted Wi-Fi attempt gets its own token. A late status response
  // from an earlier hotspot check must never overwrite the newer attempt.
  int _provisioningAttemptToken = 0;
  DateTime? _homeWifiJoinStartedAt;

  _ProvisionStage _stage = _ProvisionStage.waitingForHotspot;
  String _statusMessage = '';

  String get _hotspotName => WifiSetupScreen.hotspotNameForDevice(widget.deviceId);

  bool get _isTesting => _stage == _ProvisionStage.testingHomeWifi;

  bool get _awaitingEspConfirmation =>
      _stage == _ProvisionStage.awaitingEspConfirmation;

  // The next screen is available only after the local ESP explicitly reports
  // state=connected. Losing contact with the hotspot is never treated as a
  // successful Wi-Fi save.
  bool get _isFinished => _stage == _ProvisionStage.homeWifiSaved;

  bool get _canEnterHomeWifi =>
      _hotspotVerified &&
          !_submitting &&
          (_stage == _ProvisionStage.readyForHomeWifi ||
              _stage == _ProvisionStage.homeWifiRejected);

  bool get _isWaitingForFinalResult =>
      _stage == _ProvisionStage.testingHomeWifi ||
          _stage == _ProvisionStage.awaitingEspConfirmation;

  bool _isWithinHomeWifiJoinGracePeriod() {
    final startedAt = _homeWifiJoinStartedAt;
    if (startedAt == null) {
      return false;
    }

    return DateTime.now().difference(startedAt) < _homeWifiJoinGracePeriod;
  }

  int _remainingJoinGraceSeconds() {
    final startedAt = _homeWifiJoinStartedAt;
    if (startedAt == null) {
      return 0;
    }

    final remaining =
        _homeWifiJoinGracePeriod - DateTime.now().difference(startedAt);
    if (remaining.isNegative) {
      return 0;
    }

    return remaining.inSeconds + (remaining.inMilliseconds % 1000 == 0 ? 0 : 1);
  }

  String _h(String english, Map<String, Object?> values) =>
      context.trParams(english, values);

  String _hotspotMessage(String english) =>
      _h(english, {'hotspot': _hotspotName});

  String _temporaryConnectionMessage() {
    final seconds = _remainingJoinGraceSeconds();
    if (seconds > 0) {
      return context.trParams(
        'Still connecting your switch. It can briefly stop answering while it joins home Wi-Fi. Keep this page open. About {seconds} seconds remaining.',
        {'seconds': seconds},
      );
    }

    return context.tr(
      'Still connecting your switch. It can briefly stop answering while it joins home Wi-Fi. Keep this page open.',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _statusMessage =
    'Join $_hotspotName using the setup password printed on the device label or box.';

    // A phone often reconnects to the setup hotspot while this app is in the
    // background. Check quietly every two seconds so returning to the app gives
    // immediate feedback instead of requiring an extra, confusing button press.
    _hotspotDiscoveryTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _checkHotspot(showProgress: false),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _statusMessage = _hotspotMessage(
            'Join {hotspot} using the setup password printed on the device label or box.',
          );
        });
      }
      _checkHotspot(showProgress: false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _isFinished) {
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      if (_isWaitingForFinalResult) {
        _pollProvisionStatus();
      } else {
        _checkHotspot(showProgress: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _hotspotDiscoveryTimer?.cancel();
    _wifiNameController.dispose();
    _wifiPasswordController.dispose();
    super.dispose();
  }

  Future<Map<dynamic, dynamic>> _readProvisioningStatus() async {
    final response = await http
        .get(_statusUri)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw const FormatException('Unexpected setup status response');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid setup status JSON');
    }

    return Map<dynamic, dynamic>.from(decoded);
  }

  bool _isExpectedSwitch(Map<dynamic, dynamic> data) {
    final reportedHotspot = data['hotspot']?.toString().trim().toUpperCase();
    return reportedHotspot == null ||
        reportedHotspot.isEmpty ||
        reportedHotspot == _hotspotName;
  }

  Future<void> _checkHotspot({required bool showProgress}) async {
    if (_checkingHotspot ||
        _isTesting ||
        _isFinished ||
        (_awaitingEspConfirmation && !showProgress)) {
      return;
    }

    // Prevent a status request that started before a new Wi-Fi submission from
    // applying an older "failed" or "idle" result afterward.
    final checkToken = _provisioningAttemptToken;

    if (mounted) {
      setState(() {
        _checkingHotspot = true;
        if (showProgress && !_hotspotVerified) {
          _statusMessage = _hotspotMessage('Checking connection to {hotspot}…');
        }
      });
    }

    try {
      final data = await _readProvisioningStatus();
      if (!mounted || checkToken != _provisioningAttemptToken) return;

      if (!_isExpectedSwitch(data)) {
        throw const FormatException('Different setup hotspot');
      }

      final state = data['state']?.toString().trim().toLowerCase() ?? 'idle';
      final hotspotReady = data['hotspotReady'] != false;
      final clients = data['hotspotClients'] is num
          ? (data['hotspotClients'] as num).toInt()
          : 0;

      setState(() {
        _hotspotVerified = true;
        _statusFailures = 0;

        if (state == 'connected') {
          _statusTimer?.cancel();
          _homeWifiJoinStartedAt = null;
          _stage = _ProvisionStage.homeWifiSaved;
          _statusMessage =
          context.tr('The switch has already saved your home Wi-Fi. It will restart shortly.');
        } else if (state == 'connecting') {
          _stage = _ProvisionStage.testingHomeWifi;
          _statusMessage = context.tr('Testing your home Wi-Fi. Keep this page open.');
          _startStatusPolling();
        } else if (state == 'failed') {
          _statusTimer?.cancel();
          _homeWifiJoinStartedAt = null;
          _stage = _ProvisionStage.homeWifiRejected;
          _statusMessage =
          context.tr('The switch is connected. The previous home Wi-Fi details were not accepted. Correct them below and try again.');
        } else {
          _stage = _ProvisionStage.readyForHomeWifi;
          _statusMessage = hotspotReady
              ? (clients > 0
              ? context.tr('Phone connected to the secure switch hotspot. Enter your home Wi-Fi below.')
              : context.tr('Switch hotspot confirmed. Enter your home Wi-Fi below.'))
              : context.tr('The switch is preparing its setup hotspot. Wait a few seconds, then check again.');
        }
      });
    } catch (_) {
      if (!mounted || checkToken != _provisioningAttemptToken) return;

      setState(() {
        // Do not keep a stale hotspot confirmation after the local status
        // endpoint becomes unreachable. The customer must reconnect and let
        // the ESP report the real result again.
        _hotspotVerified = false;
        _stage = _ProvisionStage.waitingForHotspot;
        _statusMessage =
        _hotspotMessage('Connect your phone to {hotspot} first. Use the setup password printed on the device label or box.');
      });
    } finally {
      if (mounted) {
        setState(() => _checkingHotspot = false);
      }
    }
  }

  Future<void> _sendWifiDetails() async {
    final ssid = _wifiNameController.text.trim();
    final password = _wifiPasswordController.text.trim();

    if (!_hotspotVerified || !_canEnterHomeWifi) {
      _showMessage(
        _hotspotMessage('Reconnect to {hotspot} and wait for the switch status before trying again.'),
        type: AppNoticeType.warning,
      );
      return;
    }

    if (ssid.isEmpty) {
      _showMessage(context.tr('Enter your home Wi-Fi name.'));
      return;
    }

    // Invalidate any in-flight hotspot check before sending. Without this,
    // an old response can report the previous attempt as failed while the ESP
    // is already processing the newly submitted credentials.
    final attemptToken = ++_provisioningAttemptToken;

    _statusTimer?.cancel();
    setState(() {
      _submitting = true;
      _statusFailures = 0;
      _homeWifiJoinStartedAt = null;
      _stage = _ProvisionStage.testingHomeWifi;
      _statusMessage = context.tr('Sending details to the switch…');
    });

    try {
      final response = await http
          .post(
        _saveUri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'ssid': ssid, 'password': password}),
      )
          .timeout(const Duration(seconds: 10));

      if (!mounted || attemptToken != _provisioningAttemptToken) return;

      if (response.statusCode == 200 || response.statusCode == 202) {
        setState(() {
          _submitting = false;
          _homeWifiJoinStartedAt = DateTime.now();
          _stage = _ProvisionStage.testingHomeWifi;
          _statusMessage = context.tr('Testing your home Wi-Fi. Keep this page open until the switch confirms the result.');
        });
        _startStatusPolling();
      } else {
        _showHomeWifiRejected(_readMessage(response.body));
      }
    } catch (_) {
      if (!mounted || attemptToken != _provisioningAttemptToken) return;
      _homeWifiJoinStartedAt = null;
      _showHomeWifiRejected(
        _hotspotMessage('Could not send the details to the switch. Keep your phone connected to {hotspot}, then try again.'),
      );
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _pollProvisionStatus(),
    );
    _pollProvisionStatus();
  }

  Future<void> _pollProvisionStatus() async {
    if (_pollInFlight || !mounted || !_isWaitingForFinalResult) {
      return;
    }

    // A late response from a previous credential submission must never change
    // the UI for the most recent attempt.
    final attemptToken = _provisioningAttemptToken;
    _pollInFlight = true;

    try {
      final data = await _readProvisioningStatus();
      if (!mounted || attemptToken != _provisioningAttemptToken) return;

      final state = data['state']?.toString().trim().toLowerCase() ?? '';
      final message = data['message']?.toString().trim();
      _statusFailures = 0;

      if (state == 'connected') {
        _statusTimer?.cancel();
        setState(() {
          _submitting = false;
          _hotspotVerified = true;
          _homeWifiJoinStartedAt = null;
          _stage = _ProvisionStage.homeWifiSaved;
          _statusMessage =
          context.tr('Home Wi-Fi was accepted and saved. The switch is restarting now.');
        });
        return;
      }

      if (state == 'failed') {
        _statusTimer?.cancel();
        _homeWifiJoinStartedAt = null;
        _showHomeWifiRejected(
          message == null || message.isEmpty
              ? context.tr('The home Wi-Fi details were not accepted. Check the Wi-Fi name and password, then try again.')
              : message,
        );
        return;
      }

      final stillWithinGrace = _isWithinHomeWifiJoinGracePeriod();
      setState(() {
        _submitting = false;
        _stage = stillWithinGrace
            ? _ProvisionStage.testingHomeWifi
            : _ProvisionStage.awaitingEspConfirmation;
        _statusMessage = stillWithinGrace
            ? (state == 'connecting'
            ? context.tr('Connecting your switch to home Wi-Fi. Keep this page open.')
            : context.tr('Waiting for the switch to start checking your home Wi-Fi…'))
            : context.tr('Still waiting for the switch result. The app will keep checking automatically.');
      });
    } catch (_) {
      if (!mounted || attemptToken != _provisioningAttemptToken) return;

      _statusFailures++;

      // Temporary hotspot gaps are normal while the ESP changes radio channel
      // or the phone briefly loses the no-internet route. Keep polling quietly
      // through the full firmware join window instead of showing a false error.
      if (_isWithinHomeWifiJoinGracePeriod()) {
        setState(() {
          _submitting = false;
          _stage = _ProvisionStage.testingHomeWifi;
          _statusMessage = _temporaryConnectionMessage();
        });
        return;
      }

      // The result is still unknown, not failed. Continue polling in the
      // background because the ESP can return to its hotspot just after this
      // point and report state=connected or state=failed.
      setState(() {
        _submitting = false;
        _stage = _ProvisionStage.awaitingEspConfirmation;
        _statusMessage =
        context.tr('Still waiting for the switch result. The app will keep checking automatically.');
      });
    } finally {
      _pollInFlight = false;
    }
  }

  void _showHomeWifiRejected(String message) {
    if (!mounted) return;
    final wasAlreadyRejected = _stage == _ProvisionStage.homeWifiRejected;
    _statusTimer?.cancel();
    setState(() {
      _submitting = false;
      _homeWifiJoinStartedAt = null;
      _hotspotVerified = true;
      _stage = _ProvisionStage.homeWifiRejected;
      _statusMessage = message;
    });

    if (!wasAlreadyRejected) {
      _showMessage(
        context.tr('Home Wi-Fi was not accepted. Check the Wi-Fi name and password, then try again.'),
        type: AppNoticeType.error,
      );
    }
  }

  String _readMessage(String body) {
    // Firmware returns diagnostic English. The app shows the same
    // customer-friendly message in the selected app language.
    return context.tr(
      'The home Wi-Fi details were not accepted. Check the Wi-Fi name and password, then try again.',
    );
  }

  void _openActivationWait() {
    // Safety gate: DeviceActivationWaitScreen must never be opened because the
    // hotspot disappeared. Only the ESP's explicit state=connected result may
    // move the customer to the online-confirmation step.
    if (_stage != _ProvisionStage.homeWifiSaved) {
      _showMessage(
        context.tr('Wait for the switch to confirm that your home Wi-Fi was accepted.'),
        type: AppNoticeType.warning,
      );
      return;
    }

    // Stop any final local status checks before changing routes.
    _statusTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceActivationWaitScreen(
          deviceId: widget.deviceId,
          deviceName: widget.deviceName,
          recoveryMode: widget.recoveryMode,
        ),
      ),
    );
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr(widget.recoveryMode ? 'Reconnect Wi-Fi' : 'Connect Wi-Fi');
    final heading = context.trParams(
      widget.recoveryMode ? 'Reconnect {name}' : 'Connect {name}',
      {'name': widget.deviceName},
    );
    final description = context.tr(
      widget.recoveryMode
          ? 'This only updates the home Wi-Fi used by this switch. Pairing, ownership, timers and schedules stay unchanged.'
          : 'Use the secure setup hotspot, then give the switch your home Wi-Fi details. Keep the device label or box nearby.',
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: AppTheme.background,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(title),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          children: [
            Text(
              heading,
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _DeviceLabelReminderCard(
              deviceId: widget.deviceId,
              hotspotName: _hotspotName,
              recoveryMode: widget.recoveryMode,
            ),
            const SizedBox(height: 14),
            if (!_isFinished) ...[
              _OpenHotspotCard(
                recoveryMode: widget.recoveryMode,
                hotspotName: _hotspotName,
              ),
              const SizedBox(height: 12),
              _HotspotConnectionCard(
                hotspotName: _hotspotName,
                checking: _checkingHotspot,
                verified: _hotspotVerified,
                message: _statusMessage,
                onCheck: _checkingHotspot ? null : () => _checkHotspot(showProgress: true),
              ),
              const SizedBox(height: 14),
            ],
            if (_stage == _ProvisionStage.homeWifiSaved)
              _SetupSuccessCard(onContinue: _openActivationWait)
            else if (_awaitingEspConfirmation)
              _ResultNotConfirmedCard(
                hotspotName: _hotspotName,
                onCheckResult: () {
                  setState(() {
                    _stage = _ProvisionStage.waitingForHotspot;
                    _statusMessage =
                    _hotspotMessage('Reconnect to {hotspot}, then the app will check the switch result.');
                  });
                  _checkHotspot(showProgress: true);
                },
              )
            else ...[
                if (_hotspotVerified) ...[
                  _CompactStatusCard(
                    stage: _stage,
                    message: _statusMessage,
                  ),
                  const SizedBox(height: 14),
                  _HomeWifiFormCard(
                    wifiNameController: _wifiNameController,
                    wifiPasswordController: _wifiPasswordController,
                    enabled: _canEnterHomeWifi,
                    hidePassword: _hidePassword,
                    onTogglePassword: () {
                      setState(() => _hidePassword = !_hidePassword);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _canEnterHomeWifi ? _sendWifiDetails : null,
                      icon: _isTesting || _submitting
                          ? const SizedBox(
                        height: 19,
                        width: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(
                        _stage == _ProvisionStage.homeWifiRejected
                            ? Icons.refresh_rounded
                            : Icons.wifi_rounded,
                      ),
                      label: Text(
                        _isTesting || _submitting
                            ? context.tr('Testing home Wi-Fi…')
                            : _stage == _ProvisionStage.homeWifiRejected
                            ? context.tr('Try again')
                            : context.tr('Connect to home Wi-Fi'),
                      ),
                    ),
                  ),
                ],
              ],
            const SizedBox(height: 14),
            const _WifiSecurityNote(),
          ],
        ),
      ),
    );
  }
}

class _DeviceLabelReminderCard extends StatelessWidget {
  final String deviceId;
  final String hotspotName;
  final bool recoveryMode;

  const _DeviceLabelReminderCard({
    required this.deviceId,
    required this.hotspotName,
    required this.recoveryMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: AppTheme.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Keep the device label or box nearby'),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabelItem(
            icon: Icons.wifi_tethering_rounded,
            title: context.tr('Switch Wi-Fi'),
            value: hotspotName,
          ),
          const SizedBox(height: 8),
          _LabelItem(
            icon: Icons.password_rounded,
            title: context.tr('Setup password'),
            value: context.tr('Printed on the device label or product box'),
          ),
          const SizedBox(height: 8),
          _LabelItem(
            icon: Icons.memory_rounded,
            title: context.tr('Device ID'),
            value: deviceId,
          ),
          const SizedBox(height: 8),
          _LabelItem(
            icon: Icons.key_rounded,
            title: context.tr('Claim Code'),
            value: context.tr(
              recoveryMode
                  ? 'Not needed for this reconnect; keep it safe for first-time pairing.'
                  : 'Use it to add this switch to your account.',
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _LabelItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryDark, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 12,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenHotspotCard extends StatelessWidget {
  final bool recoveryMode;
  final String hotspotName;

  const _OpenHotspotCard({
    required this.recoveryMode,
    required this.hotspotName,
  });

  @override
  Widget build(BuildContext context) {
    final mainInstruction = context.tr(
      recoveryMode
          ? 'Hold the switch Wi-Fi button for 3 seconds, release it, then wait up to 10 seconds.'
          : 'Turn the switch on. Its setup hotspot should appear in your phone Wi-Fi list within about 10 seconds.',
    );

    final backupInstruction = context.tr(
      recoveryMode
          ? 'Changed your router password? Turn the switch off and on, then wait about 1 minute for this recovery hotspot. You can also hold the Wi-Fi button for 3 seconds.'
          : 'If the hotspot does not appear, check that the switch has power and wait a few seconds.',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('1. Open switch Wi-Fi'),
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            mainInstruction,
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            backupInstruction,
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 11.5,
              height: 1.36,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              context.trParams('Look for {hotspot} in phone Wi-Fi settings.', {'hotspot': hotspotName}),
              style: const TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotspotConnectionCard extends StatelessWidget {
  final String hotspotName;
  final bool checking;
  final bool verified;
  final String message;
  final VoidCallback? onCheck;

  const _HotspotConnectionCard({
    required this.hotspotName,
    required this.checking,
    required this.verified,
    required this.message,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppTheme.success : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: checking
                    ? SizedBox(
                  height: 19,
                  width: 19,
                  child: CircularProgressIndicator(
                    color: color,
                    strokeWidth: 2.2,
                  ),
                )
                    : Icon(
                  verified
                      ? Icons.check_circle_rounded
                      : Icons.phone_iphone_rounded,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  verified ? context.tr('2. Phone connected to switch') : context.tr('2. Join switch Wi-Fi'),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            verified
                ? message
                : context.trParams('In phone Wi-Fi settings, join {hotspot} with the password on the device label or box. If Android says “No internet”, keep the connection and return here.', {'hotspot': hotspotName}),
            style: TextStyle(
              color: verified ? AppTheme.darkText : AppTheme.lightText,
              fontSize: 12,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onCheck,
              icon: checking
                  ? SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 2,
                ),
              )
                  : Icon(verified ? Icons.refresh_rounded : Icons.wifi_find_rounded),
              label: Text(
                checking
                    ? context.tr('Checking switch…')
                    : verified
                    ? context.tr('Check connection again')
                    : context.tr('I joined switch Wi-Fi'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            verified
                ? context.tr('The app detected the switch automatically.')
                : context.tr('The app checks automatically when you return from phone Wi-Fi settings.'),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatusCard extends StatelessWidget {
  final _ProvisionStage stage;
  final String message;

  const _CompactStatusCard({required this.stage, required this.message});

  @override
  Widget build(BuildContext context) {
    final rejected = stage == _ProvisionStage.homeWifiRejected;
    final testing = stage == _ProvisionStage.testingHomeWifi;
    final color = rejected ? Colors.orange : (testing ? AppTheme.primary : AppTheme.success);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected
                ? Icons.warning_amber_rounded
                : testing
                ? Icons.sync_rounded
                : Icons.check_circle_rounded,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeWifiFormCard extends StatelessWidget {
  final TextEditingController wifiNameController;
  final TextEditingController wifiPasswordController;
  final bool enabled;
  final bool hidePassword;
  final VoidCallback onTogglePassword;

  const _HomeWifiFormCard({
    required this.wifiNameController,
    required this.wifiPasswordController,
    required this.enabled,
    required this.hidePassword,
    required this.onTogglePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('3. Enter home Wi-Fi'),
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('This is the Wi-Fi the switch will use every day.'),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: wifiNameController,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('Home Wi-Fi name'),
              hintText: context.tr('Network / SSID'),
              prefixIcon: const Icon(Icons.wifi_rounded),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: wifiPasswordController,
            enabled: enabled,
            obscureText: hidePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: context.tr('Home Wi-Fi password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: enabled ? onTogglePassword : null,
                icon: Icon(
                  hidePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupSuccessCard extends StatelessWidget {
  final VoidCallback onContinue;

  const _SetupSuccessCard({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 23),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Home Wi-Fi saved'),
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            context.tr('The switch accepted the new Wi-Fi details. Reconnect this phone to your normal Wi-Fi or mobile data, then let the app confirm the switch is online.'),
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.cloud_sync_rounded),
              label: Text(context.tr('I reconnected my phone')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultNotConfirmedCard extends StatelessWidget {
  final String hotspotName;
  final VoidCallback onCheckResult;

  const _ResultNotConfirmedCard({
    required this.hotspotName,
    required this.onCheckResult,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warning,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Wi-Fi result not confirmed'),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            context.tr('The switch has not confirmed the final result yet. Do not continue. The app is still checking automatically because the hotspot can pause while the switch changes Wi-Fi.'),
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 12.5,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.trParams('Keep this page open. If it still does not update, reconnect to {hotspot}, keep the phone connected even if it says “No internet”, then check again.', {'hotspot': hotspotName}),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 11.5,
              height: 1.36,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onCheckResult,
              icon: const Icon(Icons.wifi_find_rounded),
              label: Text(context.tr('Check now')),
            ),
          ),
        ],
      ),
    );
  }
}

class _WifiSecurityNote extends StatelessWidget {
  const _WifiSecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: AppTheme.lightText, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr('Your home Wi-Fi password is sent only to the local switch setup hotspot. It is not stored in Firebase.'),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
