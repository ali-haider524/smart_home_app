import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/app_ticker.dart';
import '../../services/device_service.dart';
import 'add_device_screen.dart';
import 'archived_devices_screen.dart';
import 'device_control_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DeviceService deviceService = DeviceService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: StreamBuilder<List<DeviceModel>>(
          stream: deviceService.listenAllDevices(),
          builder: (context, deviceSnapshot) {
            return StreamBuilder<DateTime>(
              stream: AppTicker.instance.stream,
              builder: (context, tickerSnapshot) {
                final devices = deviceSnapshot.data ?? [];
                final onlineCount = devices.where((d) => d.isOnline).length;
                final activeTimers =
                    devices.where((d) => d.timers['ch1']?.enabled == true).length;
                final activeSchedules = devices.fold<int>(
                  0,
                      (count, device) =>
                  count + (device.schedules['ch1']?.activeCount ?? 0),
                );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Easy Home Control',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                          Material(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(16),
                            child: IconButton(
                              tooltip: 'Archived devices',
                              icon: const Icon(Icons.inventory_2_outlined),
                              color: AppTheme.primary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ArchivedDevicesScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$onlineCount online • ${devices.length} total devices',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.lightText,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _DashboardSummary(
                        onlineCount: onlineCount,
                        totalDevices: devices.length,
                        activeTimers: activeTimers,
                        activeSchedules: activeSchedules,
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'My Devices',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkText,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Expanded(
                        child: devices.isEmpty
                            ? _EmptyDeviceCard(
                          onAddDevice: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddDeviceScreen(),
                              ),
                            );
                          },
                        )
                            : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: devices.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final device = devices[index];

                            return _DeviceCard(
                              device: device,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DeviceControlScreen(
                                      deviceId: device.id,
                                      deviceName: device.nickname,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddDeviceScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text(
                            'Add Device',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
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

class _DashboardSummary extends StatelessWidget {
  final int onlineCount;
  final int totalDevices;
  final int activeTimers;
  final int activeSchedules;

  const _DashboardSummary({
    required this.onlineCount,
    required this.totalDevices,
    required this.activeTimers,
    required this.activeSchedules,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryTile(
          icon: Icons.wifi_rounded,
          label: 'Online',
          value: '$onlineCount/$totalDevices',
          color: Colors.green,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          icon: Icons.timer_rounded,
          label: 'Timers',
          value: '$activeTimers',
          color: Colors.orange,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          icon: Icons.schedule_rounded,
          label: 'Auto',
          value: '$activeSchedules',
          color: AppTheme.primary,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 82,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 22,
              offset: const Offset(8, 12),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 14,
              offset: const Offset(-6, -6),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkText,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.lightText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ch1 = device.channels['ch1'];
    final timer = device.timers['ch1'];
    final schedule = device.schedules['ch1'];

    final switchOn = ch1?.state == true;
    final online = device.isOnline;
    final timerActive = timer?.enabled == true;
    final scheduleCount = schedule?.activeCount ?? 0;
    final scheduleActive = scheduleCount > 0;

    final statusColor = !online
        ? Colors.grey
        : switchOn
        ? Colors.green
        : AppTheme.primary;

    final statusText = !online
        ? 'Offline'
        : switchOn
        ? 'Online • Active'
        : 'Online • Standby';

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: statusColor.withOpacity(0.20)),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.12),
              blurRadius: 26,
              offset: const Offset(8, 14),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.88),
              blurRadius: 16,
              offset: const Offset(-8, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 74,
              width: 74,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.11),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 42,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${device.model} • $statusText',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.lightText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Last seen: ${device.lastSeenText}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.lightText,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DeviceBadge(
                        label: '${device.channelCount} Channel',
                        icon: Icons.device_hub_rounded,
                        color: AppTheme.primary,
                      ),
                      _DeviceBadge(
                        label: online ? 'Online' : 'Offline',
                        icon: online
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: online ? Colors.green : Colors.grey,
                      ),
                      if (timerActive)
                        _DeviceBadge(
                          label: timer?.label.isNotEmpty == true
                              ? timer!.label
                              : 'Timer',
                          icon: Icons.timer_rounded,
                          color: Colors.orange,
                        ),
                      if (scheduleActive)
                        _DeviceBadge(
                          label: '$scheduleCount schedule${scheduleCount == 1 ? '' : 's'}',
                          icon: Icons.schedule_rounded,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: statusColor),
          ],
        ),
      ),
    );
  }
}

class _DeviceBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _DeviceBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeviceCard extends StatelessWidget {
  final VoidCallback onAddDevice;

  const _EmptyDeviceCard({required this.onAddDevice});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 26,
              offset: const Offset(8, 14),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 16,
              offset: const Offset(-8, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.devices_other_rounded, size: 58),
            const SizedBox(height: 14),
            const Text(
              'No device found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first Easy Home Control device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAddDevice,
              child: const Text('Add Device'),
            ),
          ],
        ),
      ),
    );
  }
}