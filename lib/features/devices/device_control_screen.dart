import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/app_ticker.dart';
import '../../services/device_service.dart';

class DeviceControlScreen extends StatefulWidget {
  final String deviceId;

  const DeviceControlScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  static const String channelId = 'ch1';

  final DeviceService deviceService = DeviceService();
  final TextEditingController customTimerController = TextEditingController();

  TimeOfDay? onTime;
  TimeOfDay? offTime;

  int? selectedTimerMinutes;
  String? selectedTimerLabel;

  final List<_TimerOption> timerOptions = const [
    _TimerOption('15 min', 15),
    _TimerOption('30 min', 30),
    _TimerOption('1 hour', 60),
    _TimerOption('2 hours', 120),
    _TimerOption('3 hours', 180),
    _TimerOption('4 hours', 240),
    _TimerOption('8 hours', 480),
  ];

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

  Future<void> pickOnTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: onTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => onTime = picked);
    }
  }

  Future<void> pickOffTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: offTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => offTime = picked);
    }
  }

  Future<void> saveSchedule() async {
    if (onTime == null || offTime == null) {
      showMessage('Please select ON time and OFF time');
      return;
    }

    await deviceService.saveDailySchedule(
      deviceId: widget.deviceId,
      channelId: channelId,
      onHour: onTime!.hour,
      onMinute: onTime!.minute,
      offHour: offTime!.hour,
      offMinute: offTime!.minute,
    );

    showMessage('Daily schedule saved');
  }

  Future<void> cancelSchedule() async {
    await deviceService.cancelSchedule(
      deviceId: widget.deviceId,
      channelId: channelId,
    );

    showMessage('Schedule cancelled');
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String formatScheduleTime(BuildContext context, int hour, int minute) {
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Smart Switch'),
        backgroundColor: AppTheme.background,
        elevation: 0,
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
                    const _SectionTitle(title: 'Daily Schedule'),
                    const SizedBox(height: 14),
                    if (schedule != null && schedule.enabled)
                      _ActiveInfoCard(
                        icon: Icons.schedule_rounded,
                        title: 'Schedule Active',
                        value:
                        '${formatScheduleTime(context, schedule.onHour, schedule.onMinute)} → ${formatScheduleTime(context, schedule.offHour, schedule.offMinute)}',
                        subtitle: 'Repeats daily',
                        color: Colors.blue,
                      ),
                    if (schedule != null && schedule.enabled)
                      const SizedBox(height: 12),
                    _ScheduleCard(
                      onTime: onTime,
                      offTime: offTime,
                      onPickOnTime: pickOnTime,
                      onPickOffTime: pickOffTime,
                      onSave: saveSchedule,
                      onCancel: cancelSchedule,
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

class _ScheduleCard extends StatelessWidget {
  final TimeOfDay? onTime;
  final TimeOfDay? offTime;
  final VoidCallback onPickOnTime;
  final VoidCallback onPickOffTime;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _ScheduleCard({
    required this.onTime,
    required this.offTime,
    required this.onPickOnTime,
    required this.onPickOffTime,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickOnTime,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    onTime == null ? 'ON Time' : 'ON ${onTime!.format(context)}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickOffTime,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(
                    offTime == null
                        ? 'OFF Time'
                        : 'OFF ${offTime!.format(context)}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('Save Daily Schedule'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCancel,
              child: const Text('Cancel Schedule'),
            ),
          ),
        ],
      ),
    );
  }
}

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