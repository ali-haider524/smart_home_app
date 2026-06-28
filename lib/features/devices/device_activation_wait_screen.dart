import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';

/// Shown after the ESP accepts WiFi details through its local AP.
///
/// The phone normally has to leave EHC_SETUP_A7F92 and reconnect to the home
/// WiFi/mobile data before Firebase can report the device online again.
class DeviceActivationWaitScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const DeviceActivationWaitScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
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

  bool get _timedOut => _elapsedSeconds >= 120 && !_deviceOnline;

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

            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SoftBackButton(onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  Center(
                    child: Container(
                      height: 116,
                      width: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_deviceOnline ? Colors.green : AppTheme.primary)
                            .withValues(alpha: 0.12),
                        boxShadow: [
                          BoxShadow(
                            color: (_deviceOnline ? Colors.green : AppTheme.primary)
                                .withValues(alpha: 0.18),
                            blurRadius: 28,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _deviceOnline
                            ? Icons.check_circle_rounded
                            : Icons.wifi_find_rounded,
                        size: 64,
                        color: _deviceOnline ? Colors.green : AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      _deviceOnline
                          ? '${widget.deviceName} is online'
                          : 'Connecting your device',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _deviceOnline
                          ? 'WiFi setup is complete. You can now control this switch from the app.'
                          : _timedOut
                          ? 'The device is not online yet. Check your home WiFi name/password, then try setup again.'
                          : 'The device is restarting and joining your home WiFi. This usually takes less than a minute.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _StatusCard(
                    isOnline: _deviceOnline,
                    timedOut: _timedOut,
                    elapsedSeconds: _elapsedSeconds,
                  ),
                  const SizedBox(height: 16),
                  if (!_deviceOnline)
                    const _ReconnectPhoneHint(),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _deviceOnline ? _finish : null,
                      icon: Icon(
                        _deviceOnline
                            ? Icons.home_rounded
                            : Icons.hourglass_top_rounded,
                      ),
                      label: Text(
                        _deviceOnline ? 'Open My Devices' : 'Waiting for device...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (_timedOut) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Back to WiFi Setup'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isOnline;
  final bool timedOut;
  final int elapsedSeconds;

  const _StatusCard({
    required this.isOnline,
    required this.timedOut,
    required this.elapsedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline
        ? Colors.green
        : timedOut
        ? Colors.orange
        : AppTheme.primary;

    final title = isOnline
        ? 'Device connected'
        : timedOut
        ? 'Connection taking longer than expected'
        : 'Waiting for online heartbeat';

    final subtitle = isOnline
        ? 'Firebase received a fresh lastSeen update.'
        : 'Elapsed: ${elapsedSeconds.clamp(0, 999)} seconds';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(8, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 14,
            offset: const Offset(-6, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isOnline ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
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
  const _ReconnectPhoneHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reconnect your phone from EHC_SETUP_A7F92 to your normal home WiFi or mobile data. Then this screen will detect the device online.',
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
