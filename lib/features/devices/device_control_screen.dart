import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../models/energy_estimate.dart';
import '../../models/schedule_model.dart';
import '../../models/timer_model.dart';
import '../../services/app_ticker.dart';
import '../../services/device_service.dart';
import 'device_settings_screen.dart';
import 'energy_estimate_settings_screen.dart';
import 'wifi_setup_screen.dart';

/// Device control keeps the existing Firebase and ESP contract unchanged.
///
/// This screen only presents the current device state and sends the same
/// commands through [DeviceService] as before. Relay confirmation, timers,
/// schedules, settings and Wi-Fi setup remain handled by their existing code.
class DeviceControlScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const DeviceControlScreen({
    super.key,
    required this.deviceId,
    this.deviceName = 'Smart Switch',
  });

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  static const String channelId = 'ch1';

  final DeviceService deviceService = DeviceService();
  late String _deviceName;
  late final Stream<EnergyEstimateSettings> _energySettingsStream;

  // Cloud control is intentionally confirmed only from the ESP-reported
  // /state value. The app never flips the UI optimistically.
  static const Duration _commandConfirmationTimeout = Duration(seconds: 8);
  Timer? _commandConfirmationTimer;
  bool _commandPending = false;
  bool? _requestedRelayState;
  int _commandAttempt = 0;
  bool _confirmationCheckQueued = false;

  // These are presentation presets only. The timer service still accepts any
  // custom duration up to 24 hours, exactly as before.
  static const List<_TimerOption> _timerOptions = [
    _TimerOption('15 min', '15m', 15),
    _TimerOption('30 min', '30m', 30),
    _TimerOption('1 hour', '1h', 60),
    _TimerOption('2 hours', '2h', 120),
    _TimerOption('3 hours', '3h', 180),
    _TimerOption('4 hours', '4h', 240),
    _TimerOption('5 hours', '5h', 300),
    _TimerOption('6 hours', '6h', 360),
    _TimerOption('7 hours', '7h', 420),
    _TimerOption('8 hours', '8h', 480),
    _TimerOption('9 hours', '9h', 540),
    _TimerOption('10 hours', '10h', 600),
  ];

  @override
  void initState() {
    super.initState();
    _deviceName = widget.deviceName.trim().isEmpty
        ? 'Smart Switch'
        : widget.deviceName.trim();
    _energySettingsStream =
        deviceService.listenEnergyEstimateSettings(widget.deviceId);
  }

  @override
  void dispose() {
    _commandConfirmationTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendPowerCommand(bool currentState) async {
    if (_commandPending) {
      return;
    }

    final requestedState = !currentState;
    final attempt = ++_commandAttempt;

    setState(() {
      _commandPending = true;
      _requestedRelayState = requestedState;
    });

    try {
      await deviceService.setChannelState(
        deviceId: widget.deviceId,
        channelId: channelId,
        state: requestedState,
      );

      // A very fast device callback can confirm the state before this write
      // Future returns. In that case, do not start a stale timeout.
      if (!mounted || attempt != _commandAttempt || !_commandPending) {
        return;
      }

      _commandConfirmationTimer?.cancel();
      _commandConfirmationTimer = Timer(
        _commandConfirmationTimeout,
            () {
          if (!mounted || attempt != _commandAttempt || !_commandPending) {
            return;
          }

          _clearPendingPowerCommand();
          showMessage(
            context.tr(
              'Device did not confirm the command. Check its connection and try again.',
            ),
            type: AppNoticeType.error,
          );
        },
      );
    } catch (_) {
      if (!mounted || attempt != _commandAttempt) {
        return;
      }

      _clearPendingPowerCommand();
      showMessage(
        context.tr(
          'Could not send the command. Check your internet connection and try again.',
        ),
        type: AppNoticeType.error,
      );
    }
  }

  void _queuePowerConfirmation(bool actualState) {
    if (!_commandPending ||
        _requestedRelayState != actualState ||
        _confirmationCheckQueued) {
      return;
    }

    _confirmationCheckQueued = true;

    // The latest device state arrives inside a StreamBuilder. Delay the state
    // update until after this build to avoid calling setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confirmationCheckQueued = false;

      if (!mounted ||
          !_commandPending ||
          _requestedRelayState != actualState) {
        return;
      }

      _clearPendingPowerCommand();
      showMessage(
        actualState
            ? context.tr('Switch turned ON.')
            : context.tr('Switch turned OFF.'),
        type: AppNoticeType.success,
      );
    });
  }

  void _clearPendingPowerCommand() {
    _commandConfirmationTimer?.cancel();
    _commandConfirmationTimer = null;

    if (!mounted) {
      _commandPending = false;
      _requestedRelayState = null;
      return;
    }

    setState(() {
      _commandPending = false;
      _requestedRelayState = null;
    });
  }

  Future<bool> _startRunTimer({
    required int durationMinutes,
    required String label,
  }) async {
    if (durationMinutes < 1) {
      showMessage(context.tr('Please select or enter timer duration'));
      return false;
    }

    if (durationMinutes > 1440) {
      showMessage(context.tr('Maximum timer allowed is 24 hours'));
      return false;
    }

    try {
      await deviceService.startTimer(
        deviceId: widget.deviceId,
        channelId: channelId,
        durationMinutes: durationMinutes,
        label: label,
      );

      if (!mounted) return false;
      showMessage('${context.tr('Timer started')}: $label');
      return true;
    } catch (_) {
      if (!mounted) return false;
      showMessage(
        context.tr('Could not start timer. Please try again.'),
        type: AppNoticeType.error,
      );
      return false;
    }
  }

  Future<bool> _cancelRunTimer() async {
    try {
      await deviceService.cancelTimer(
        deviceId: widget.deviceId,
        channelId: channelId,
      );

      if (!mounted) return false;
      showMessage(context.tr('Timer cancelled'));
      return true;
    } catch (_) {
      if (!mounted) return false;
      showMessage(
        context.tr('Could not cancel timer. Please try again.'),
        type: AppNoticeType.error,
      );
      return false;
    }
  }

  Future<void> _openTimerSheet(
      TimerModel? timer, {
        int? initialMinutes,
      }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _TimerSetupSheet(
          activeTimer: timer,
          options: _timerOptions,
          initialMinutes: initialMinutes,
          onStart: _startRunTimer,
          onCancel: _cancelRunTimer,
        );
      },
    );
  }

  Future<void> _openEnergyEstimateSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EnergyEstimateSettingsScreen(
          deviceId: widget.deviceId,
          deviceName: _deviceName,
        ),
      ),
    );
  }

  Future<void> openScheduleManager(
      List<ScheduleItem> currentItems,
      ) async {
    final updatedItems = await showModalBottomSheet<List<ScheduleItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ScheduleManagerSheet(initialItems: currentItems);
      },
    );

    if (updatedItems == null) {
      return;
    }

    try {
      await deviceService.saveSchedules(
        deviceId: widget.deviceId,
        channelId: channelId,
        items: updatedItems,
      );

      showMessage(
        updatedItems.isEmpty
            ? context.tr('All schedules removed')
            : '${context.l10n.scheduleCount(updatedItems.length)} ${context.tr('saved')}',
      );
    } on ArgumentError catch (error) {
      showMessage(error.message.toString());
    } catch (_) {
      showMessage(context.tr('Could not save schedules. Please try again.'));
    }
  }

  void showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  Future<void> openDeviceSettings() async {
    final result = await Navigator.push<DeviceSettingsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceSettingsScreen(
          deviceId: widget.deviceId,
          initialDeviceName: _deviceName,
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result.removed) {
      Navigator.pop(context);
      return;
    }

    if (result.nickname != null && result.nickname!.trim().isNotEmpty) {
      setState(() => _deviceName = result.nickname!.trim());
    }

    if (result.openWiFiSetup) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WifiSetupScreen(
            deviceId: widget.deviceId,
            deviceName: _deviceName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        titleSpacing: 20,
        title: Text(
          _deviceName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.darkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _RoundActionButton(
              tooltip: context.tr('Device settings'),
              icon: Icons.settings_outlined,
              onTap: openDeviceSettings,
            ),
          ),
        ],
      ),
      body: StreamBuilder<DeviceModel?>(
        stream: deviceService.listenDevice(widget.deviceId),
        builder: (context, deviceSnapshot) {
          return StreamBuilder<DateTime>(
            stream: AppTicker.instance.stream,
            builder: (context, tickerSnapshot) {
              final device = deviceSnapshot.data;

              if (device == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final channel = device.channels[channelId];
              final timer = device.timers[channelId];
              final schedules =
                  device.schedules[channelId]?.orderedItems ?? const <ScheduleItem>[];
              final activeScheduleCount =
                  schedules.where((item) => item.enabled).length;
              final state = channel?.state == true;
              final online = device.isOnline;

              _queuePowerConfirmation(state);

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
                children: [
                  _PowerControlCard(
                    online: online,
                    state: state,
                    lastSeenText: device.lastSeenText,
                    commandPending: _commandPending,
                    requestedState: _requestedRelayState,
                    onTap: online && !_commandPending
                        ? () => _sendPowerCommand(state)
                        : null,
                  ),
                  const SizedBox(height: 18),
                  _QuickTimerPanel(
                    timer: timer,
                    onOpenTimer: () => _openTimerSheet(timer),
                    onQuickTimer: (minutes) =>
                        _openTimerSheet(timer, initialMinutes: minutes),
                  ),
                  const SizedBox(height: 12),
                  _SimpleActionCard(
                    icon: Icons.calendar_month_outlined,
                    iconColor: AppTheme.automation,
                    title: 'Schedules',
                    subtitle: activeScheduleCount == 0
                        ? 'Set automatic ON/OFF times'
                        : '$activeScheduleCount active ${activeScheduleCount == 1 ? 'schedule' : 'schedules'}',
                    actionLabel: activeScheduleCount == 0 ? 'Set up' : 'Manage',
                    onTap: () => openScheduleManager(schedules),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<EnergyEstimateSettings>(
                    stream: _energySettingsStream,
                    builder: (context, energySnapshot) {
                      final settings = energySnapshot.data ??
                          EnergyEstimateSettings.empty;
                      return _EnergyEstimateSummaryCard(
                        settings: settings,
                        timer: timer,
                        onTap: _openEnergyEstimateSettings,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _DeviceDetailsCard(device: device),
                ],
              );
            },
          );
        },
      ),
    );
  }

}

class _TimerOption {
  final String label;
  final String shortLabel;
  final int minutes;

  const _TimerOption(this.label, this.shortLabel, this.minutes);
}

String _durationLabel(int minutes) {
  if (minutes <= 0) return '0 min';
  if (minutes < 60) return '$minutes min';
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 hour' : '$hours hours';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours h $remainingMinutes min';
}

class _RoundActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _RoundActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.outline),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryDark, size: 22),
          ),
        ),
      ),
    );
  }
}

class _PowerControlCard extends StatelessWidget {
  final bool online;
  final bool state;
  final String lastSeenText;
  final bool commandPending;
  final bool? requestedState;
  final VoidCallback? onTap;

  const _PowerControlCard({
    required this.online,
    required this.state,
    required this.lastSeenText,
    required this.commandPending,
    required this.requestedState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = !online
        ? Colors.blueGrey
        : state
        ? AppTheme.success
        : AppTheme.primary;
    final requestedLabel = requestedState == true
        ? context.tr('ON')
        : context.tr('OFF');
    final title = !online
        ? context.tr('Device is offline')
        : commandPending
        ? '${context.tr('Sending')} $requestedLabel ${context.tr('command')}'
        : state
        ? context.tr('Power is ON')
        : context.tr('Power is OFF');
    final detail = !online
        ? '${context.tr('Last seen')} $lastSeenText'
        : commandPending
        ? context.tr('Waiting for device confirmation')
        : state
        ? context.tr('Tap the button to turn it off')
        : context.tr('Tap the button to turn it on');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatusBadge(
                icon: online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                label: online ? context.tr('ONLINE') : context.tr('OFFLINE'),
                color: accent,
              ),
              const Spacer(),
              Text(
                online
                    ? context.tr('Ready')
                    : '${context.tr('Last seen')} $lastSeenText',
                style: const TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            enabled: onTap != null,
            label: commandPending
                ? '${context.tr('Sending')} $requestedLabel ${context.tr('command')}'
                : state
                ? context.tr('Turn switch off')
                : context.tr('Turn switch on'),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 112,
                  width: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(onTap == null ? 0.10 : 0.14),
                    border: Border.all(
                      color: accent.withOpacity(onTap == null ? 0.20 : 0.34),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 82,
                        width: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.24),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          color: Colors.white.withOpacity(
                            onTap == null ? 0.58 : 1,
                          ),
                          size: 39,
                        ),
                      ),
                      if (commandPending)
                        const SizedBox(
                          height: 112,
                          width: 112,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.lightText,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PanelHeading({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryDark, size: 18),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.darkText,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _QuickTimerPanel extends StatelessWidget {
  final TimerModel? timer;
  final VoidCallback onOpenTimer;
  final ValueChanged<int> onQuickTimer;

  const _QuickTimerPanel({
    required this.timer,
    required this.onOpenTimer,
    required this.onQuickTimer,
  });

  @override
  Widget build(BuildContext context) {
    final running = timer?.enabled == true;
    final activeLabel = timer?.label.trim().isNotEmpty == true
        ? timer!.label.trim()
        : _durationLabel(timer?.durationMinutes ?? 0);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeading(
            icon: Icons.timer_outlined,
            title: 'Quick timer',
            actionLabel: running ? 'Manage' : 'All options',
            onAction: onOpenTimer,
          ),
          const SizedBox(height: 11),
          if (running) ...[
            Material(
              color: AppTheme.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: onOpenTimer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          color: AppTheme.warning,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Timer is active',
                              style: TextStyle(
                                color: AppTheme.darkText,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              activeLabel,
                              style: const TextStyle(
                                color: AppTheme.lightText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.lightText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 11),
          ] else
            const Padding(
              padding: EdgeInsets.only(left: 1, bottom: 10),
              child: Text(
                'Turn the switch off automatically after',
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12,
                ),
              ),
            ),
          Row(
            children: [
              _QuickTimerButton(label: '15m', onTap: () => onQuickTimer(15)),
              const SizedBox(width: 7),
              _QuickTimerButton(label: '30m', onTap: () => onQuickTimer(30)),
              const SizedBox(width: 7),
              _QuickTimerButton(label: '1h', onTap: () => onQuickTimer(60)),
              const SizedBox(width: 7),
              _QuickTimerButton(label: '2h', onTap: () => onQuickTimer(120)),
              const SizedBox(width: 7),
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenTimer,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 42),
                  ),
                  child: const Text('More'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickTimerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickTimerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 42),
          backgroundColor: AppTheme.surfaceSoft,
          foregroundColor: AppTheme.primaryDark,
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _SimpleActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _SimpleActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: _softCardDecoration(),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                actionLabel,
                style: const TextStyle(
                  color: AppTheme.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.primaryDark,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergyEstimateSummaryCard extends StatelessWidget {
  final EnergyEstimateSettings settings;
  final TimerModel? timer;
  final VoidCallback onTap;

  const _EnergyEstimateSummaryCard({
    required this.settings,
    required this.timer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final configured = settings.isConfigured;
    final activeTimer = timer?.enabled == true && (timer?.durationMinutes ?? 0) > 0;
    final perHour = configured ? settings.estimateForMinutes(60) : null;
    final timerEstimate = configured && activeTimer
        ? settings.estimateForMinutes(timer!.durationMinutes)
        : null;
    final timerLabel = activeTimer
        ? (timer!.label.trim().isNotEmpty
            ? timer!.label.trim()
            : _durationLabel(timer!.durationMinutes))
        : null;

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _softCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.bolt_outlined,
                      color: AppTheme.success,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated energy',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Approximation from wattage and time',
                          style: TextStyle(
                            color: AppTheme.lightText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Estimate only',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!configured)
                _EnergySetupPrompt(onTap: onTap)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _EnergyStat(
                        label: 'Appliance',
                        value: '${settings.ratedWatts} W',
                        detail: 'Power rating',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _EnergyStat(
                        label: 'Per hour',
                        value: perHour!.energyLabel,
                        detail: perHour.costLabel == null
                            ? 'Cost not set'
                            : '${perHour.costLabel} / hour',
                      ),
                    ),
                  ],
                ),
                if (timerEstimate != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppTheme.primaryDark,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Timer total · $timerLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.darkText,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            timerEstimate.costLabel == null
                                ? timerEstimate.energyLabel
                                : '${timerEstimate.energyLabel} · ${timerEstimate.costLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 17),
                    label: const Text('Edit estimate'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergySetupPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _EnergySetupPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Add appliance watts to see hourly and timer estimates.',
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Set up'),
          ),
        ],
      ),
    );
  }
}

class _EnergyStat extends StatelessWidget {
  final String label;
  final String value;
  final String detail;

  const _EnergyStat({
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.lightText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.darkText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.lightText,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceDetailsCard extends StatelessWidget {
  final DeviceModel device;

  const _DeviceDetailsCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _softCardDecoration(),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 1),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Colors.blueGrey,
                size: 21,
              ),
            ),
            title: const Text(
              'Device details',
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              '${device.model} · ${device.firmwareVersion}',
              style: const TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
              ),
            ),
            children: [
              _DeviceDetailLine(label: 'Device ID', value: device.id),
              _DeviceDetailLine(label: 'Model', value: device.model),
              _DeviceDetailLine(label: 'Firmware', value: device.firmwareVersion),
              _DeviceDetailLine(
                label: 'Channels',
                value: '${device.channelCount} channel${device.channelCount == 1 ? '' : 's'}',
              ),
              _DeviceDetailLine(label: 'Last seen', value: device.lastSeenText),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DeviceDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.darkText,
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

class _TimerSetupSheet extends StatefulWidget {
  final TimerModel? activeTimer;
  final List<_TimerOption> options;
  final int? initialMinutes;
  final Future<bool> Function({
  required int durationMinutes,
  required String label,
  }) onStart;
  final Future<bool> Function() onCancel;

  const _TimerSetupSheet({
    required this.activeTimer,
    required this.options,
    required this.initialMinutes,
    required this.onStart,
    required this.onCancel,
  });

  @override
  State<_TimerSetupSheet> createState() => _TimerSetupSheetState();
}

class _TimerSetupSheetState extends State<_TimerSetupSheet> {
  final TextEditingController _customController = TextEditingController();
  int? _selectedMinutes;
  bool _customMode = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  _TimerOption? get _selectedOption {
    for (final option in widget.options) {
      if (option.minutes == _selectedMinutes) return option;
    }
    return null;
  }

  int? get _customMinutes => int.tryParse(_customController.text.trim());

  int? get _finalMinutes {
    if (_customMode) {
      final minutes = _customMinutes;
      return minutes != null && minutes > 0 ? minutes : null;
    }
    return _selectedMinutes;
  }

  String? get _finalLabel {
    final minutes = _finalMinutes;
    if (minutes == null) return null;
    if (_customMode) return _durationLabel(minutes);
    return _selectedOption?.label ?? _durationLabel(minutes);
  }

  void _chooseOption(_TimerOption option) {
    setState(() {
      _selectedMinutes = option.minutes;
      _customMode = false;
      _customController.clear();
    });
  }

  void _chooseCustom() {
    setState(() {
      _selectedMinutes = null;
      _customMode = true;
    });
  }

  Future<void> _start() async {
    final minutes = _finalMinutes;
    final label = _finalLabel;

    if (minutes == null || label == null) {
      return;
    }

    setState(() => _submitting = true);
    final started = await widget.onStart(
      durationMinutes: minutes,
      label: label,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (started) Navigator.pop(context);
  }

  Future<void> _cancel() async {
    setState(() => _submitting = true);
    final cancelled = await widget.onCancel();

    if (!mounted) return;
    setState(() => _submitting = false);
    if (cancelled) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeTimer?.enabled == true;
    final minutes = _finalMinutes;
    final label = _finalLabel;
    final isReady = minutes != null && label != null && minutes <= 1440;
    final largerOptions = widget.options.where((item) => item.minutes >= 180).toList();

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          13,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 5,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set timer',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'The switch will turn off automatically.',
                          style: TextStyle(
                            color: AppTheme.lightText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (active) ...[
                const SizedBox(height: 16),
                _TimerRunningSheetCard(
                  label: widget.activeTimer!.label.trim().isNotEmpty
                      ? widget.activeTimer!.label.trim()
                      : _durationLabel(widget.activeTimer!.durationMinutes),
                  busy: _submitting,
                  onCancel: _cancel,
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Quick choices',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.options.take(4).map((option) {
                  return _DurationChip(
                    label: option.shortLabel,
                    selected: !_customMode && _selectedMinutes == option.minutes,
                    onTap: _submitting ? null : () => _chooseOption(option),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'More hour choices',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: largerOptions.map((option) {
                  return _DurationChip(
                    label: option.shortLabel,
                    selected: !_customMode && _selectedMinutes == option.minutes,
                    onTap: _submitting ? null : () => _chooseOption(option),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _chooseCustom,
                icon: const Icon(Icons.edit_outlined, size: 19),
                label: const Text('Use custom minutes'),
              ),
              if (_customMode) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customController,
                  autofocus: true,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Custom duration',
                    hintText: 'Example: 45 or 120',
                    suffixText: 'minutes',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
              ],
              if (_customMode && _customMinutes != null && _customMinutes! > 1440)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Maximum timer allowed is 24 hours.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              if (isReady)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    active
                        ? 'This will replace the current timer with $label.'
                        : 'Selected: $label',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.lightText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submitting || !isReady ? null : _start,
                  icon: _submitting
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    active ? 'Replace timer' : 'Start timer',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerRunningSheetCard extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onCancel;

  const _TimerRunningSheetCard({
    required this.label,
    required this.busy,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warning.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppTheme.warning,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Timer running',
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: onTap == null ? null : (_) => onTap!(),
      selectedColor: AppTheme.primary.withOpacity(0.14),
      backgroundColor: AppTheme.surfaceSoft,
      side: BorderSide(
        color: selected ? AppTheme.primary.withOpacity(0.36) : AppTheme.outline,
      ),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryDark : AppTheme.lightText,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    );
  }
}

BoxDecoration _softCardDecoration() {
  return BoxDecoration(
    color: AppTheme.card,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.035),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
    ],
  );
}

class _ScheduleManagerSheet extends StatefulWidget {
  final List<ScheduleItem> initialItems;

  const _ScheduleManagerSheet({
    required this.initialItems,
  });

  @override
  State<_ScheduleManagerSheet> createState() => _ScheduleManagerSheetState();
}

class _ScheduleManagerSheetState extends State<_ScheduleManagerSheet> {
  static const int _maxSchedules = 6;

  late List<ScheduleItem> _items;

  @override
  void initState() {
    super.initState();

    _items = widget.initialItems
        .map((item) => item.copyWith())
        .toList(growable: true)
      ..sort((left, right) => left.id.compareTo(right.id));
  }

  String? _nextSlotId() {
    for (var number = 1; number <= _maxSchedules; number++) {
      final id = 's$number';
      if (_items.every((item) => item.id != id)) {
        return id;
      }
    }

    return null;
  }

  void _addSchedule() {
    final id = _nextSlotId();

    if (id == null) {
      _showMessage('Maximum $_maxSchedules schedules are allowed.');
      return;
    }

    setState(() {
      _items.add(ScheduleItem.empty(id));
      _items.sort((left, right) => left.id.compareTo(right.id));
    });
  }

  void _removeSchedule(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
  }

  void _updateSchedule(ScheduleItem updatedItem) {
    setState(() {
      final index = _items.indexWhere((item) => item.id == updatedItem.id);

      if (index >= 0) {
        _items[index] = updatedItem;
      }
    });
  }

  Future<void> _pickTime(ScheduleItem item, bool isOnTime) async {
    final selectedMinutes = isOnTime ? item.onMinutes : item.offMinutes;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: selectedMinutes ~/ 60,
        minute: selectedMinutes % 60,
      ),
    );

    if (picked == null) {
      return;
    }

    _updateSchedule(
      item.copyWith(
        onMinutes: isOnTime ? picked.hour * 60 + picked.minute : null,
        offMinutes: isOnTime ? null : picked.hour * 60 + picked.minute,
      ),
    );
  }

  void _toggleDay(ScheduleItem item, int dayIndex) {
    final bit = 1 << dayIndex;
    final updatedMask = item.daysMask ^ bit;

    _updateSchedule(item.copyWith(daysMask: updatedMask));
  }

  void _save() {
    for (final item in _items) {
      if (!item.enabled) {
        continue;
      }

      if (!item.hasAnyDaySelected) {
        _showMessage('${item.label}: select at least one day.');
        return;
      }

      if (item.onMinutes == item.offMinutes) {
        _showMessage('${item.label}: ON and OFF time cannot be the same.');
        return;
      }
    }

    Navigator.pop(context, _items);
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  String _formatTime(BuildContext context, int minutes) {
    return TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    ).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              height: 5,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Schedules',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkText,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Choose ON/OFF time and repeat days',
                        style: TextStyle(color: AppTheme.lightText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _items.isEmpty
                  ? _EmptyScheduleState(onAdd: _addSchedule)
                  : ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final item = _items[index];

                  return _ScheduleEditorCard(
                    item: item,
                    formatTime: _formatTime,
                    onToggleEnabled: (enabled) {
                      _updateSchedule(item.copyWith(enabled: enabled));
                    },
                    onPickOnTime: () => _pickTime(item, true),
                    onPickOffTime: () => _pickTime(item, false),
                    onToggleDay: (dayIndex) => _toggleDay(item, dayIndex),
                    onDelete: () => _removeSchedule(item.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (_items.length < _maxSchedules)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _addSchedule,
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Add Schedule (${_items.length}/$_maxSchedules)'),
                ),
              ),
            if (_items.length < _maxSchedules) const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Schedules'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyScheduleState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyScheduleState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 54,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No schedules yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a recurring weekly schedule. It keeps working locally after WiFi disconnects.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.lightText),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleEditorCard extends StatelessWidget {
  final ScheduleItem item;
  final String Function(BuildContext context, int minutes) formatTime;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onPickOnTime;
  final VoidCallback onPickOffTime;
  final ValueChanged<int> onToggleDay;
  final VoidCallback onDelete;

  const _ScheduleEditorCard({
    required this.item,
    required this.formatTime,
    required this.onToggleEnabled,
    required this.onPickOnTime,
    required this.onPickOffTime,
    required this.onToggleDay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: item.enabled ? 1 : 0.62,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: item.enabled
                ? Colors.blue.withOpacity(0.22)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    item.id.replaceFirst('s', ''),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: item.enabled,
                  activeThumbColor: AppTheme.primary,
                  onChanged: onToggleEnabled,
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete schedule',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickOnTime,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('ON ${formatTime(context, item.onMinutes)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickOffTime,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text('OFF ${formatTime(context, item.offMinutes)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Repeat on',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: List.generate(ScheduleItem.dayShortNames.length, (index) {
                final selected = item.isEnabledOnDayIndex(index);

                return ChoiceChip(
                  label: Text(ScheduleItem.dayShortNames[index]),
                  selected: selected,
                  onSelected: (_) => onToggleDay(index),
                  selectedColor: AppTheme.primary.withOpacity(0.16),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: selected ? AppTheme.primary : AppTheme.lightText,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

