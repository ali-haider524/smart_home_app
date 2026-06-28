import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import 'device_activation_wait_screen.dart';

class WifiSetupScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const WifiSetupScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

enum _ProvisionStage {
  form,
  connecting,
  failed,
  connected,
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  static final Uri _saveUri = Uri.parse('http://192.168.4.1/save');
  static final Uri _statusUri = Uri.parse('http://192.168.4.1/status');

  final wifiNameController = TextEditingController();
  final wifiPasswordController = TextEditingController();

  Timer? _statusTimer;
  bool _pollInFlight = false;
  bool hidePassword = true;
  bool isLoading = false;
  int _statusFailures = 0;
  _ProvisionStage _stage = _ProvisionStage.form;
  String _statusMessage =
      'Enter your home WiFi details. The device will test them before saving.';

  @override
  void dispose() {
    _statusTimer?.cancel();
    wifiNameController.dispose();
    wifiPasswordController.dispose();
    super.dispose();
  }

  Future<void> sendWifiDetails() async {
    final ssid = wifiNameController.text.trim();
    final password = wifiPasswordController.text.trim();

    if (ssid.isEmpty) {
      showMessage('Please enter WiFi name');
      return;
    }

    _statusTimer?.cancel();
    setState(() {
      isLoading = true;
      _statusFailures = 0;
      _stage = _ProvisionStage.connecting;
      _statusMessage = 'Sending WiFi details to the device...';
    });

    try {
      final response = await http
          .post(
        _saveUri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'ssid': ssid, 'password': password}),
      )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 202) {
        setState(() {
          isLoading = false;
          _stage = _ProvisionStage.connecting;
          _statusMessage =
          'Trying to connect to your WiFi. Keep your phone on EHC_SETUP_A7F92 for a moment.';
        });
        _startStatusPolling();
      } else {
        _showProvisionFailure(_readMessage(response.body));
      }
    } catch (_) {
      if (!mounted) return;
      _showProvisionFailure(
        'Could not reach the device. Connect your phone to EHC_SETUP_A7F92, then try again.',
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
    if (_pollInFlight || !mounted || _stage != _ProvisionStage.connecting) {
      return;
    }

    _pollInFlight = true;

    try {
      final response = await http
          .get(_statusUri)
          .timeout(const Duration(seconds: 4));

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw const FormatException('Unexpected status response');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Invalid status JSON');
      }

      final data = Map<dynamic, dynamic>.from(decoded);
      final state = data['state']?.toString() ?? '';
      final message = data['message']?.toString() ?? 'Checking device...';
      _statusFailures = 0;

      if (state == 'connected') {
        _statusTimer?.cancel();
        setState(() {
          _stage = _ProvisionStage.connected;
          _statusMessage =
          'WiFi connected successfully. The device is restarting to join Easy Home Control.';
        });
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) _openActivationWait();
        return;
      }

      if (state == 'failed') {
        _statusTimer?.cancel();
        _showProvisionFailure(message);
        return;
      }

      setState(() => _statusMessage = message);
    } catch (_) {
      _statusFailures++;

      if (!mounted) return;

      if (_statusFailures >= 8) {
        _statusTimer?.cancel();
        _showProvisionFailure(
          'The setup hotspot stopped responding. Reconnect to EHC_SETUP_A7F92 and check the WiFi details before trying again.',
        );
      } else {
        setState(() {
          _statusMessage =
          'Still checking the device. Keep this phone connected to EHC_SETUP_A7F92.';
        });
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _showProvisionFailure(String message) {
    if (!mounted) return;
    _statusTimer?.cancel();
    setState(() {
      isLoading = false;
      _stage = _ProvisionStage.failed;
      _statusMessage = message;
    });
  }

  String _readMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {
      // Fall back to a generic message below.
    }
    return 'Device could not accept WiFi details. Please try again.';
  }

  void _openActivationWait() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceActivationWaitScreen(
          deviceId: widget.deviceId,
          deviceName: widget.deviceName,
        ),
      ),
    );
  }

  void showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  Color get _statusColor {
    switch (_stage) {
      case _ProvisionStage.failed:
        return Colors.red;
      case _ProvisionStage.connected:
        return Colors.green;
      case _ProvisionStage.connecting:
        return Colors.orange;
      case _ProvisionStage.form:
        return AppTheme.primary;
    }
  }

  IconData get _statusIcon {
    switch (_stage) {
      case _ProvisionStage.failed:
        return Icons.wifi_off_rounded;
      case _ProvisionStage.connected:
        return Icons.wifi_rounded;
      case _ProvisionStage.connecting:
        return Icons.wifi_find_rounded;
      case _ProvisionStage.form:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connecting = _stage == _ProvisionStage.connecting ||
        _stage == _ProvisionStage.connected;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SoftBackButton(
                    onTap: connecting ? () {} : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'WiFi Setup',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Connect your device',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkText,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'First connect your phone to EHC_SETUP_A7F92 hotspot. The device now checks your WiFi before it saves anything.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.lightText,
                ),
              ),
              const SizedBox(height: 24),
              _DeviceInfoCard(
                deviceId: widget.deviceId,
                deviceName: widget.deviceName,
              ),
              const SizedBox(height: 20),
              _ProvisionStatusCard(
                color: _statusColor,
                icon: _statusIcon,
                message: _statusMessage,
                connecting: connecting,
              ),
              const SizedBox(height: 20),
              _SoftCard(
                child: Column(
                  children: [
                    TextField(
                      controller: wifiNameController,
                      enabled: !connecting,
                      decoration: const InputDecoration(
                        hintText: 'WiFi Name / SSID',
                        prefixIcon: Icon(Icons.wifi_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: wifiPasswordController,
                      enabled: !connecting,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        hintText: 'WiFi Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: connecting
                              ? null
                              : () => setState(
                                () => hidePassword = !hidePassword,
                          ),
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
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: connecting || isLoading ? null : sendWifiDetails,
                  icon: connecting || isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Icon(
                    _stage == _ProvisionStage.failed
                        ? Icons.refresh_rounded
                        : Icons.send_rounded,
                  ),
                  label: Text(
                    connecting
                        ? 'Checking WiFi connection...'
                        : _stage == _ProvisionStage.failed
                        ? 'Try WiFi Details Again'
                        : 'Send WiFi Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Security note: WiFi password is sent only to the ESP setup hotspot. It is not stored in Firebase and is saved to ESP memory only after WiFi connects.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.lightText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProvisionStatusCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  final bool connecting;

  const _ProvisionStatusCard({
    required this.color,
    required this.icon,
    required this.message,
    required this.connecting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: connecting
                ? Padding(
              padding: const EdgeInsets.all(11),
              child: CircularProgressIndicator(
                color: color,
                strokeWidth: 2.4,
              ),
            )
                : Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.darkText,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const _DeviceInfoCard({
    required this.deviceId,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.memory_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  deviceId,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  final Widget child;

  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(10, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.95),
            blurRadius: 18,
            offset: const Offset(-8, -8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SoftBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SoftBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(6, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                blurRadius: 14,
                offset: const Offset(-6, -6),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.darkText,
          ),
        ),
      ),
    );
  }
}
