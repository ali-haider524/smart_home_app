import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../models/schedule_model.dart';
import '../../services/app_ticker.dart';
import '../../services/device_service.dart';
import 'device_settings_screen.dart';
import 'wifi_setup_screen.dart';

/// Phase 6B refreshes only the Device Control presentation layer.
///
/// The stable Firebase/ESP contract remains unchanged:
/// - Flutter writes the command path only.
/// - ESP reports the real relay state.
/// - A power command is confirmed only after the ESP reports /state.
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
  final TextEditingController customTimerController = TextEditingController();
  late String _deviceName;

  int? selectedTimerMinutes;
  String? selectedTimerLabel;

  // Cloud control is intentionally confirmed only from the ESP-reported
  // /state value. The app never flips the UI optimistically.
  static const Duration _commandConfirmationTimeout = Duration(seconds: 8);
  Timer? _commandConfirmationTimer;
  bool _commandPending = false;
  bool? _requestedRelayState;
  int _commandAttempt = 0;
  bool _confirmationCheckQueued = false;

  final List<_TimerOption> timerOptions = const [
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
  }

  @override
  void dispose() {
    _commandConfirmationTimer?.cancel();
    customTimerController.dispose();
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
            'Device did not confirm the command. Check its connection and try again.',
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
        'Could not send the command. Check your internet connection and try again.',
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
        'Switch turned ${actualState ? 'ON' : 'OFF'}.',
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

  Future<void> startRunTimer() async {
    final customMinutes = int.tryParse(customTimerController.text.trim());

    int? finalMinutes;
    String? finalLabel;

    if (customMinutes != null && customMinutes > 0) {
      finalMinutes = customMinutes;
      finalLabel = '$customMinutes min';
    } else {
      finalMinutes = selectedTimerMinutes;
      finalLabel = selectedTimerLabel;
    }

    if (finalMinutes == null || finalLabel == null) {
      showMessage('Please select or enter timer duration');
      return;
    }

    if (finalMinutes > 1440) {
      showMessage('Maximum timer allowed is 24 hours');
      return;
    }

    await deviceService.startTimer(
      deviceId: widget.deviceId,
      channelId: channelId,
      durationMinutes: finalMinutes,
      label: finalLabel,
    );

    customTimerController.clear();

    if (mounted) {
      setState(() {
        selectedTimerMinutes = null;
        selectedTimerLabel = null;
      });
    }

    showMessage('Timer started: $finalLabel');
  }

  Future<void> cancelRunTimer() async {
    await deviceService.cancelTimer(
      deviceId: widget.deviceId,
      channelId: channelId,
    );

    showMessage('Timer cancelled');
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
            ? 'All schedules removed'
            : '${updatedItems.length} schedule${updatedItems.length == 1 ? '' : 's'} saved',
      );
    } on ArgumentError catch (error) {
      showMessage(error.message.toString());
    } catch (_) {
      showMessage('Could not save schedules. Please try again.');
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
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _deviceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.darkText,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Smart switch control',
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _RoundActionButton(
              tooltip: 'Device settings',
              icon: Icons.settings_rounded,
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

              final ch1 = device.channels[channelId];
              final timer = device.timers[channelId];
              final schedule = device.schedules[channelId];

              final state = ch1?.state == true;
              final status = ch1?.status ?? 'OFF';
              final online = device.isOnline;

              _queuePowerConfirmation(state);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DeviceHeroCard(
                      deviceName: _deviceName,
                      online: online,
                      state: state,
                      status: status,
                      lastSeenText: device.lastSeenText,
                      commandPending: _commandPending,
                      requestedState: _requestedRelayState,
                      onTap: online && !_commandPending
                          ? () => _sendPowerCommand(state)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _DeviceMetaStrip(
                      online: online,
                      lastSeenText: device.lastSeenText,
                      model: device.model,
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      icon: Icons.timer_outlined,
                      title: 'Quick timer',
                      detail: timer?.enabled == true
                          ? 'Timer currently running'
                          : 'Set a one-time switch-off timer',
                    ),
                    const SizedBox(height: 12),
                    if (timer != null && timer.enabled) ...[
                      _TimerRunningBanner(timerLabel: timer.label, durationMinutes: timer.durationMinutes),
                      const SizedBox(height: 10),
                    ],
                    _TimerControlCard(
                      timerOptions: timerOptions,
                      selectedMinutes: selectedTimerMinutes,
                      customTimerController: customTimerController,
                      onChanged: (option) {
                        setState(() {
                          selectedTimerMinutes = option?.minutes;
                          selectedTimerLabel = option?.label;
                        });
                      },
                      onStart: startRunTimer,
                      onCancel: cancelRunTimer,
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      icon: Icons.calendar_month_outlined,
                      title: 'Automations',
                      detail: 'Weekly schedules run on the device',
                      actionLabel: 'Manage',
                      onAction: () {
                        openScheduleManager(schedule?.orderedItems ?? const []);
                      },
                    ),
                    const SizedBox(height: 12),
                    _ScheduleSummaryCard(
                      schedules: schedule?.orderedItems ?? const [],
                      onManage: () {
                        openScheduleManager(schedule?.orderedItems ?? const []);
                      },
                    ),
                    const SizedBox(height: 20),
                    _DeviceDetailsCard(device: device),
                  ],
                ),
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
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppTheme.primaryDark),
          ),
        ),
      ),
    );
  }
}

class _DeviceHeroCard extends StatelessWidget {
  final String deviceName;
  final bool online;
  final bool state;
  final String status;
  final String lastSeenText;
  final bool commandPending;
  final bool? requestedState;
  final VoidCallback? onTap;

  const _DeviceHeroCard({
    required this.deviceName,
    required this.online,
    required this.state,
    required this.status,
    required this.lastSeenText,
    required this.commandPending,
    required this.requestedState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stateColor = !online
        ? Colors.blueGrey
        : state
        ? const Color(0xFF16A34A)
        : AppTheme.primary;
    final requestedLabel = requestedState == true ? 'ON' : 'OFF';
    final statusTitle = !online
        ? 'Device is offline'
        : commandPending
        ? 'Sending $requestedLabel command'
        : state
        ? 'Power is ON'
        : 'Power is OFF';
    final statusDetail = !online
        ? 'Last seen $lastSeenText'
        : commandPending
        ? 'Waiting for the switch to confirm the relay state.'
        : state
        ? 'Tap the power button to switch it off.'
        : 'Tap the power button to switch it on.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            stateColor,
            Color.lerp(stateColor, AppTheme.primaryDark, 0.38)!,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: stateColor.withOpacity(0.23),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroStatusChip(
                      icon: online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      label: online ? 'ONLINE' : 'OFFLINE',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Channel 1 • $status',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Semantics(
                button: true,
                enabled: onTap != null,
                label: commandPending
                    ? 'Sending $requestedLabel command'
                    : state
                    ? 'Turn switch off'
                    : 'Turn switch on',
                child: Material(
                  color: Colors.white.withOpacity(0.15),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      height: 98,
                      width: 98,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 82,
                            width: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            child: Icon(
                              Icons.power_settings_new_rounded,
                              size: 42,
                              color: Colors.white.withOpacity(onTap == null ? 0.55 : 1),
                            ),
                          ),
                          if (commandPending)
                            const SizedBox(
                              height: 96,
                              width: 96,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(
                  commandPending
                      ? Icons.sync_rounded
                      : online
                      ? (state ? Icons.lightbulb_rounded : Icons.power_rounded)
                      : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusDetail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
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

class _HeroStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroStatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceMetaStrip extends StatelessWidget {
  final bool online;
  final String lastSeenText;
  final String model;

  const _DeviceMetaStrip({
    required this.online,
    required this.lastSeenText,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          _MetaCell(
            icon: online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            label: online ? 'Connection' : 'Status',
            value: online ? 'Online' : 'Offline',
            color: online ? const Color(0xFF16A34A) : Colors.blueGrey,
          ),
          const _MetaDivider(),
          _MetaCell(
            icon: Icons.history_rounded,
            label: 'Last seen',
            value: lastSeenText,
            color: AppTheme.primary,
          ),
          const _MetaDivider(),
          _MetaCell(
            icon: Icons.memory_rounded,
            label: 'Model',
            value: model,
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetaCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.darkText,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.lightText,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaDivider extends StatelessWidget {
  const _MetaDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 1,
      color: AppTheme.lightText.withOpacity(0.12),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppTheme.primaryDark, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                detail,
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
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _TimerRunningBanner extends StatelessWidget {
  final String timerLabel;
  final int durationMinutes;

  const _TimerRunningBanner({
    required this.timerLabel,
    required this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final readableLabel = timerLabel.trim().isEmpty
        ? '${durationMinutes > 0 ? durationMinutes : 0} min'
        : timerLabel.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timer_rounded,
              color: Color(0xFFD97706),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 13,
                  height: 1.25,
                ),
                children: [
                  const TextSpan(text: 'Timer running • '),
                  TextSpan(
                    text: readableLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const TextSpan(text: '\nThe switch will turn off automatically.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerControlCard extends StatelessWidget {
  final List<_TimerOption> timerOptions;
  final int? selectedMinutes;
  final TextEditingController customTimerController;
  final ValueChanged<_TimerOption?> onChanged;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const _TimerControlCard({
    required this.timerOptions,
    required this.selectedMinutes,
    required this.customTimerController,
    required this.onChanged,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a duration',
            style: TextStyle(
              color: AppTheme.darkText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: timerOptions.map((option) {
              final selected = option.minutes == selectedMinutes;

              return ChoiceChip(
                label: Text(option.shortLabel),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => onChanged(selected ? null : option),
                selectedColor: AppTheme.primary.withOpacity(0.16),
                backgroundColor: AppTheme.background,
                side: BorderSide(
                  color: selected
                      ? AppTheme.primary.withOpacity(0.35)
                      : AppTheme.lightText.withOpacity(0.10),
                ),
                labelStyle: TextStyle(
                  color: selected ? AppTheme.primaryDark : AppTheme.lightText,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: customTimerController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Or enter custom minutes',
              hintText: 'Example: 15, 45, 120',
              prefixIcon: const Icon(Icons.edit_calendar_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start timer'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: BorderSide(
                      color: const Color(0xFFF59E0B).withOpacity(0.42),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleSummaryCard extends StatelessWidget {
  final List<ScheduleItem> schedules;
  final VoidCallback onManage;

  const _ScheduleSummaryCard({
    required this.schedules,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final activeSchedules =
    schedules.where((item) => item.enabled).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _softCardDecoration(),
      child: activeSchedules.isEmpty
          ? _EmptyAutomationContent(onManage: onManage)
          : Column(
        children: [
          ...activeSchedules.take(2).map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ScheduleSummaryRow(item: item),
            ),
          ),
          if (activeSchedules.length > 2)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '+${activeSchedules.length - 2} more schedule${activeSchedules.length == 3 ? '' : 's'}',
                style: const TextStyle(
                  color: AppTheme.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.edit_calendar_rounded, size: 19),
              label: const Text('Manage schedules'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryDark,
                side: BorderSide(color: AppTheme.primary.withOpacity(0.26)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAutomationContent extends StatelessWidget {
  final VoidCallback onManage;

  const _EmptyAutomationContent({required this.onManage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF7C3AED),
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No schedules yet',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Automate power for selected days and times.',
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onManage,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
          ),
          child: const Text(
            'Add',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _ScheduleSummaryRow extends StatelessWidget {
  final ScheduleItem item;

  const _ScheduleSummaryRow({required this.item});

  String _time(BuildContext context, int minutes) {
    return TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    ).format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppTheme.primaryDark,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.daysSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_time(context, item.onMinutes)} – ${_time(context, item.offMinutes)}',
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
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
      decoration: _softCardShadowDecoration(),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              height: 38,
              width: 38,
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
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text(
              'Model, firmware and identification',
              style: TextStyle(color: AppTheme.lightText, fontSize: 12),
            ),
            children: [
              _DetailLine(label: 'Device ID', value: device.id),
              _DetailLine(label: 'Model', value: device.model),
              _DetailLine(label: 'Firmware', value: device.firmwareVersion),
              _DetailLine(
                label: 'Channels',
                value:
                '${device.channelCount} channel${device.channelCount == 1 ? '' : 's'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
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

BoxDecoration _softCardShadowDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.035),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
    ],
  );
}

BoxDecoration _softCardDecoration() {
  return BoxDecoration(
    color: AppTheme.card,
    borderRadius: BorderRadius.circular(22),
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

