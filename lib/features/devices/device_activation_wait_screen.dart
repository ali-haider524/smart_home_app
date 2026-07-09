import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';

/// Step 3 of device setup.
///
/// This screen keeps the existing online-heartbeat listener and only changes
/// how progress and recovery guidance are shown to the customer.
class DeviceActivationWaitScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  /// Used after Wi-Fi recovery for an already registered device. It changes
  /// only the guidance text; the existing heartbeat listener stays unchanged.
  final bool recoveryMode;

  const DeviceActivationWaitScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.recoveryMode = false,
  });

  @override
  State<DeviceActivationWaitScreen> createState() =>
      _DeviceActivationWaitScreenState();
}

class _DeviceActivationWaitScreenState extends State<DeviceActivationWaitScreen> {
  final _deviceService = DeviceService();

  Timer? _ticker;
  late final DateTime _startedAt;
  bool _deviceOnline = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _elapsedSeconds => DateTime.now().difference(_startedAt).inSeconds;

  String _hotspotNameForDevice(String deviceId) {
    final clean = deviceId.trim().toUpperCase();
    final suffix = clean.length <= 5 ? clean : clean.substring(clean.length - 5);
    return 'EHC_SETUP_$suffix';
  }

  // Wi-Fi recovery may include one ESP restart plus a Firebase TLS retry.
  // Give the registered device a little longer before suggesting that the
  // customer re-enters credentials.
  bool get _timedOut =>
      _elapsedSeconds >= (widget.recoveryMode ? 180 : 120) && !_deviceOnline;

  void _markOnline() {
    if (_deviceOnline) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _deviceOnline = true);
      }
    });
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: StreamBuilder<DeviceModel?>(
          stream: _deviceService.listenDevice(widget.deviceId),
          builder: (context, snapshot) {
            final device = snapshot.data;

            if (device?.isOnline == true) {
              _markOnline();
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _BackButton(onTap: () => Navigator.pop(context)),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                context.tr(widget.recoveryMode ? 'Confirm reconnect' : 'Finish setup'),
                                style: TextStyle(
                                  color: AppTheme.darkText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const _StepBadge(),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _FlowProgress(
                          online: _deviceOnline,
                          recoveryMode: widget.recoveryMode,
                        ),
                        const SizedBox(height: 38),
                        Center(
                          child: _ConnectionIcon(
                            online: _deviceOnline,
                            timedOut: _timedOut,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _deviceOnline
                              ? context.trParams('{name} is ready', {'name': widget.deviceName})
                              : _timedOut
                              ? context.tr('Still waiting for the switch')
                              : widget.recoveryMode
                              ? context.tr('Confirming your switch')
                              : context.tr('Connecting your switch'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 25,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _deviceOnline
                              ? context.tr('Wi-Fi recovery is complete. You can now control this switch from the app.')
                              : _timedOut
                              ? context.tr('Check the Wi-Fi name and password, then return to the previous step and try again.')
                              : widget.recoveryMode
                              ? context.tr('Your phone is back on a normal connection. We are waiting for the registered switch to come online.')
                              : context.tr('The switch is restarting and joining your home Wi-Fi. This usually takes less than a minute.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.lightText,
                            fontSize: 14,
                            height: 1.42,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _ConnectionProgress(
                          online: _deviceOnline,
                          timedOut: _timedOut,
                        ),
                        const SizedBox(height: 14),
                        _ConnectionStatusCard(
                          online: _deviceOnline,
                          timedOut: _timedOut,
                          elapsedSeconds: _elapsedSeconds,
                        ),
                        if (!_deviceOnline) ...[
                          const SizedBox(height: 12),
                          _ReconnectPhoneHint(
                            hotspotName: _hotspotNameForDevice(widget.deviceId),
                          ),
                        ],
                        // This page is inside a SingleChildScrollView. A Spacer
                        // needs a bounded height and can break layout on smaller
                        // screens, so use normal spacing before the actions.
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _deviceOnline ? _finish : null,
                            icon: Icon(
                              _deviceOnline
                                  ? Icons.home_rounded
                                  : Icons.hourglass_top_rounded,
                            ),
                            label: Text(
                              _deviceOnline ? context.tr('Open home') : context.tr('Waiting for switch…'),
                            ),
                          ),
                        ),
                        if (_timedOut) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: Text(context.tr('Back to Wi-Fi setup')),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FlowProgress extends StatelessWidget {
  final bool online;
  final bool recoveryMode;

  const _FlowProgress({
    required this.online,
    required this.recoveryMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProgressStep(
          label: context.tr(recoveryMode ? 'Saved' : 'Pair'),
          state: _ProgressState.done,
          icon: Icons.check_rounded,
        ),
        const _ProgressLine(active: true),
        _ProgressStep(
          label: context.tr('Wi-Fi'),
          state: _ProgressState.done,
          icon: Icons.check_rounded,
        ),
        const _ProgressLine(active: true),
        _ProgressStep(
          label: context.tr('Ready'),
          state: online ? _ProgressState.done : _ProgressState.current,
          icon: online ? Icons.check_rounded : Icons.cloud_sync_rounded,
        ),
      ],
    );
  }
}

enum _ProgressState { done, current, pending }

class _ProgressStep extends StatelessWidget {
  final String label;
  final _ProgressState state;
  final IconData icon;

  const _ProgressStep({
    required this.label,
    required this.state,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final active = state == _ProgressState.done || state == _ProgressState.current;
    final color = active ? AppTheme.primaryDark : AppTheme.lightText;

    return Expanded(
      child: Row(
        children: [
          Container(
            height: 28,
            width: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppTheme.primaryDark : AppTheme.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 15,
              color: active ? Colors.white : AppTheme.lightText,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final bool active;

  const _ProgressLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 1,
      color: active ? AppTheme.primaryDark : AppTheme.outline,
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        context.tr('Step 3 of 3'),
        style: const TextStyle(
          color: AppTheme.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ConnectionIcon extends StatelessWidget {
  final bool online;
  final bool timedOut;

  const _ConnectionIcon({required this.online, required this.timedOut});

  @override
  Widget build(BuildContext context) {
    final color = online
        ? AppTheme.success
        : timedOut
        ? AppTheme.warning
        : AppTheme.primary;
    final icon = online
        ? Icons.check_rounded
        : timedOut
        ? Icons.wifi_off_rounded
        : Icons.wifi_find_rounded;

    return Container(
      height: 92,
      width: 92,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1.5),
      ),
      child: Icon(icon, color: color, size: 45),
    );
  }
}

class _ConnectionProgress extends StatelessWidget {
  final bool online;
  final bool timedOut;

  const _ConnectionProgress({required this.online, required this.timedOut});

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
        children: [
          _ProgressRow(
            icon: Icons.check_circle_rounded,
            title: 'Wi-Fi details saved',
            subtitle: 'The switch accepted your home network details.',
            color: AppTheme.success,
          ),
          const _ProgressDivider(),
          _ProgressRow(
            icon: online ? Icons.check_circle_rounded : Icons.sync_rounded,
            title: 'Joining your home Wi-Fi',
            subtitle: online
                ? 'The switch has joined your network.'
                : timedOut
                ? 'This step needs attention.'
                : 'The switch is restarting now.',
            color: online
                ? AppTheme.success
                : timedOut
                ? AppTheme.warning
                : AppTheme.primary,
            spinning: !online && !timedOut,
          ),
          const _ProgressDivider(),
          _ProgressRow(
            icon: online ? Icons.check_circle_rounded : Icons.cloud_outlined,
            title: 'Ready in Easy Home Control',
            subtitle: online
                ? 'You can now control this switch from Home.'
                : 'We are waiting for the switch to come online.',
            color: online ? AppTheme.success : AppTheme.lightText,
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool spinning;

  const _ProgressRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: spinning
              ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(color: color, strokeWidth: 2.2),
          )
              : Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(title),
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr(subtitle),
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressDivider extends StatelessWidget {
  const _ProgressDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 17, top: 7, bottom: 7),
      child: SizedBox(
        height: 11,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppTheme.outline,
        ),
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  final bool online;
  final bool timedOut;
  final int elapsedSeconds;

  const _ConnectionStatusCard({
    required this.online,
    required this.timedOut,
    required this.elapsedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final color = online
        ? AppTheme.success
        : timedOut
        ? AppTheme.warning
        : AppTheme.primary;
    final title = context.tr(
      online
          ? 'Switch is online'
          : timedOut
          ? 'Connection is taking longer'
          : 'Waiting for switch to come online',
    );
    final subtitle = online
        ? context.tr('Setup is complete.')
        : context.trParams(
            'Elapsed time: {seconds} seconds',
            {'seconds': elapsedSeconds.clamp(0, 999)},
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.17)),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
            color: color,
            size: 23,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
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

class _ReconnectPhoneHint extends StatelessWidget {
  final String hotspotName;

  const _ReconnectPhoneHint({required this.hotspotName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.17)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              context.trParams(
                'Reconnect this phone from {hotspot} to your normal Wi-Fi or mobile data. The app will confirm the switch automatically once it comes online.',
                {'hotspot': hotspotName},
              ),
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

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          width: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.darkText,
            size: 21,
          ),
        ),
      ),
    );
  }
}
