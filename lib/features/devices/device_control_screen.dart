import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../models/schedule_model.dart';
import '../../services/app_ticker.dart';
import '../../services/device_service.dart';
import 'device_settings_screen.dart';
import 'wifi_setup_screen.dart';

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

  final List<_TimerOption> timerOptions = const [
    _TimerOption('1 hour', 60),
    _TimerOption('2 hours', 120),
    _TimerOption('3 hours', 180),
    _TimerOption('4 hours', 240),
    _TimerOption('5 hours', 300),
    _TimerOption('6 hours', 360),
    _TimerOption('7 hours', 420),
    _TimerOption('8 hours', 480),
    _TimerOption('9 hours', 540),
    _TimerOption('10 hours', 600),
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
    customTimerController.dispose();
    super.dispose();
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
        title: Text(_deviceName),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Device settings',
            onPressed: openDeviceSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 4),
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

              final cardColor = !online
                  ? Colors.grey
                  : state
                  ? Colors.green
                  : AppTheme.primary;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PowerCard(
                      online: online,
                      state: state,
                      status: status,
                      color: cardColor,
                      lastSeenText: device.lastSeenText,
                      onTap: online
                          ? () {
                        deviceService.toggleChannel(
                          deviceId: widget.deviceId,
                          channelId: channelId,
                          currentState: state,
                        );
                      }
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _StatusSummaryCard(
                      online: online,
                      lastSeenText: device.lastSeenText,
                      firmwareVersion: device.firmwareVersion,
                      model: device.model,
                    ),
                    const SizedBox(height: 26),
                    const _SectionTitle(title: 'Quick Run Timer'),
                    const SizedBox(height: 12),
                    if (timer != null && timer.enabled)
                      _ActiveInfoCard(
                        icon: Icons.timer_rounded,
                        title: 'Timer Active',
                        value: timer.label.isEmpty
                            ? '${timer.durationMinutes} min'
                            : timer.label,
                        subtitle:
                        'Relay will turn ${timer.durationMinutes > 0 ? 'OFF after ${timer.durationMinutes} min' : 'OFF automatically'}',
                        color: Colors.orange,
                      ),
                    if (timer != null && timer.enabled)
                      const SizedBox(height: 12),
                    _TimerSelectorCard(
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
                    const SizedBox(height: 30),
                    const _SectionTitle(title: 'Weekly Schedules'),
                    const SizedBox(height: 14),
                    _ScheduleOverviewCard(
                      schedules: schedule?.orderedItems ?? const [],
                      onManage: () {
                        openScheduleManager(
                          schedule?.orderedItems ?? const [],
                        );
                      },
                    ),
                    const SizedBox(height: 26),
                    _DeviceInfoCard(device: device),
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
  final int minutes;

  const _TimerOption(this.label, this.minutes);
}

class _ActiveInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _ActiveInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
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

class _StatusSummaryCard extends StatelessWidget {
  final bool online;
  final String lastSeenText;
  final String firmwareVersion;
  final String model;

  const _StatusSummaryCard({
    required this.online,
    required this.lastSeenText,
    required this.firmwareVersion,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final color = online ? Colors.green : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _MiniStatusItem(
            icon: Icons.wifi_rounded,
            label: online ? 'Online' : 'Offline',
            color: color,
          ),
          const SizedBox(width: 10),
          _MiniStatusItem(
            icon: Icons.history_rounded,
            label: lastSeenText,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 10),
          _MiniStatusItem(
            icon: Icons.memory_rounded,
            label: model,
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _MiniStatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniStatusItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerSelectorCard extends StatelessWidget {
  final List<_TimerOption> timerOptions;
  final int? selectedMinutes;
  final TextEditingController customTimerController;
  final ValueChanged<_TimerOption?> onChanged;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const _TimerSelectorCard({
    required this.timerOptions,
    required this.selectedMinutes,
    required this.customTimerController,
    required this.onChanged,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final selectedOption = selectedMinutes == null
        ? null
        : timerOptions.firstWhere((e) => e.minutes == selectedMinutes);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<_TimerOption>(
            value: selectedOption,
            decoration: InputDecoration(
              labelText: 'Select duration',
              prefixIcon: const Icon(Icons.timer_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            items: timerOptions.map((option) {
              return DropdownMenuItem<_TimerOption>(
                value: option,
                child: Text(option.label),
              );
            }).toList(),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: customTimerController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Custom minutes',
              hintText: 'Example: 2, 3, 45',
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
                    label: const Text('Start Timer'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleOverviewCard extends StatelessWidget {
  final List<ScheduleItem> schedules;
  final VoidCallback onManage;

  const _ScheduleOverviewCard({
    required this.schedules,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final activeSchedules =
    schedules.where((item) => item.enabled).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(6, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 14,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  activeSchedules.isEmpty
                      ? 'No active schedules'
                      : '${activeSchedules.length} active schedule${activeSchedules.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onManage,
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (activeSchedules.isEmpty)
            const Text(
              'Create up to 6 recurring schedules and choose the days for each one.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.lightText,
              ),
            )
          else
            ...activeSchedules.take(3).map(
                  (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SchedulePreviewRow(item: item),
              ),
            ),
          if (activeSchedules.length > 3)
            Text(
              '+${activeSchedules.length - 3} more schedule${activeSchedules.length - 3 == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: Text(
                activeSchedules.isEmpty
                    ? 'Add Schedules'
                    : 'Manage Schedules',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulePreviewRow extends StatelessWidget {
  final ScheduleItem item;

  const _SchedulePreviewRow({required this.item});

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
        color: Colors.blue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_time(context, item.onMinutes)} → ${_time(context, item.offMinutes)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            item.daysSummary,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.lightText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
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

// =====================================================
class _PowerCard extends StatelessWidget {
  final bool online;
  final bool state;
  final String status;
  final Color color;
  final String lastSeenText;
  final VoidCallback? onTap;

  const _PowerCard({
    required this.online,
    required this.state,
    required this.status,
    required this.color,
    required this.lastSeenText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = online && state;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: active ? Colors.green : AppTheme.card,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onTap,
            child: Container(
              height: 116,
              width: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                active ? Colors.white.withOpacity(0.18) : color.withOpacity(0.10),
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 70,
                color: active ? Colors.white : color,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            state ? 'Switch is ON' : 'Switch is OFF',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            online ? 'Device Online • Status: $status' : 'Device Offline',
            style: TextStyle(
              color: active ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last seen: $lastSeenText',
            style: TextStyle(
              fontSize: 12,
              color: active ? Colors.white70 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final DeviceModel device;

  const _DeviceInfoCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device Info',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Device ID: ${device.id}'),
          Text('Model: ${device.model}'),
          Text('Firmware: ${device.firmwareVersion}'),
          Text('Channels: ${device.channelCount}'),
          Text('Last Seen: ${device.lastSeenText}'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}