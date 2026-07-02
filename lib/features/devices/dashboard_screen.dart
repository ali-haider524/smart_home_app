import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/app_ticker.dart';
import '../../services/device_service.dart';
import 'add_device_screen.dart';
import 'archived_devices_screen.dart';
import 'device_control_screen.dart';

/// Phase 6A.1 keeps the existing Dashboard data, navigation, and control
/// contracts unchanged. It only refines the visual layout to be more compact
/// and to avoid small-screen RenderFlex overflows.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DeviceService _deviceService = DeviceService();
  late final Stream<List<DeviceModel>> _activeDevicesStream;

  @override
  void initState() {
    super.initState();
    // Keeps Phase 5A-2 secure read behavior: only mapped user devices are read.
    _activeDevicesStream = _deviceService.listenAllDevices();
  }

  void _openAddDevice() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
  }

  void _openArchivedDevices() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArchivedDevicesScreen()),
    );
  }

  void _openDevice(DeviceModel device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceControlScreen(
          deviceId: device.id,
          deviceName: device.nickname,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: StreamBuilder<List<DeviceModel>>(
          stream: _activeDevicesStream,
          builder: (context, deviceSnapshot) {
            return StreamBuilder<DateTime>(
              stream: AppTicker.instance.stream,
              builder: (context, _) {
                final devices = deviceSnapshot.data ?? const <DeviceModel>[];
                final overview = _DashboardOverview.fromDevices(devices);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _DashboardHeader(
                          subtitle: _dashboardSubtitle(overview),
                          onOpenArchived: _openArchivedDevices,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _HomeStatusPanel(
                          overview: overview,
                          onAddDevice: _openAddDevice,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _OverviewGrid(overview: overview),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: _DevicesSectionHeader(
                          deviceCount: devices.length,
                          onAddDevice: _openAddDevice,
                        ),
                      ),
                    ),
                    if (deviceSnapshot.hasError)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: _DashboardMessageCard(
                            icon: Icons.cloud_off_rounded,
                            title: 'Could not load devices',
                            detail:
                            'Check your internet connection, then return to this screen.',
                          ),
                        ),
                      )
                    else if (deviceSnapshot.connectionState ==
                        ConnectionState.waiting &&
                        !deviceSnapshot.hasData)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 42),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (devices.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverToBoxAdapter(
                            child: _EmptyDevicesCard(onAddDevice: _openAddDevice),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                final itemIndex = index ~/ 2;

                                if (index.isOdd) {
                                  return const SizedBox(height: 12);
                                }

                                final device = devices[itemIndex];
                                return _DeviceOverviewCard(
                                  device: device,
                                  onTap: () => _openDevice(device),
                                );
                              },
                              childCount: devices.length == 1
                                  ? 1
                                  : (devices.length * 2) - 1,
                            ),
                          ),
                        ),
                    if (devices.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
                        sliver: SliverToBoxAdapter(
                          child: _AddAnotherDeviceCard(onTap: _openAddDevice),
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 34)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _dashboardSubtitle(_DashboardOverview overview) {
    if (overview.totalDevices == 0) {
      return 'Set up your first smart switch to get started.';
    }

    if (overview.onlineDevices == 0) {
      return 'Your devices are offline. Check their power and Wi-Fi.';
    }

    if (overview.activeDevices > 0) {
      return '${overview.activeDevices} device${overview.activeDevices == 1 ? '' : 's'} active right now.';
    }

    return '${overview.onlineDevices} device${overview.onlineDevices == 1 ? '' : 's'} ready to control.';
  }
}

class _DashboardOverview {
  final int totalDevices;
  final int onlineDevices;
  final int activeDevices;
  final int activeTimers;
  final int activeSchedules;

  const _DashboardOverview({
    required this.totalDevices,
    required this.onlineDevices,
    required this.activeDevices,
    required this.activeTimers,
    required this.activeSchedules,
  });

  factory _DashboardOverview.fromDevices(List<DeviceModel> devices) {
    var onlineDevices = 0;
    var activeDevices = 0;
    var activeTimers = 0;
    var activeSchedules = 0;

    for (final device in devices) {
      if (device.isOnline) onlineDevices++;
      if (device.channels['ch1']?.state == true) activeDevices++;
      if (device.timers['ch1']?.enabled == true) activeTimers++;
      activeSchedules += device.schedules['ch1']?.activeCount ?? 0;
    }

    return _DashboardOverview(
      totalDevices: devices.length,
      onlineDevices: onlineDevices,
      activeDevices: activeDevices,
      activeTimers: activeTimers,
      activeSchedules: activeSchedules,
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String subtitle;
  final VoidCallback onOpenArchived;

  const _DashboardHeader({
    required this.subtitle,
    required this.onOpenArchived,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Easy Home Control',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.65,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeaderAction(onTap: onOpenArchived),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Tooltip(
          message: 'Archived devices',
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStatusPanel extends StatelessWidget {
  final _DashboardOverview overview;
  final VoidCallback onAddDevice;

  const _HomeStatusPanel({
    required this.overview,
    required this.onAddDevice,
  });

  @override
  Widget build(BuildContext context) {
    final hasDevices = overview.totalDevices > 0;
    final hasOnlineDevices = overview.onlineDevices > 0;

    final title = !hasDevices
        ? 'Start with your first device'
        : hasOnlineDevices
        ? 'Your home is connected'
        : 'Waiting for your devices';

    final detail = !hasDevices
        ? 'Add an Easy Home Control switch and connect it to Wi-Fi.'
        : hasOnlineDevices
        ? '${overview.onlineDevices} of ${overview.totalDevices} device${overview.totalDevices == 1 ? '' : 's'} online now.'
        : 'Restore power or Wi-Fi, then the device will check in again.';

    final icon = !hasDevices
        ? Icons.home_outlined
        : hasOnlineDevices
        ? Icons.wifi_tethering_rounded
        : Icons.wifi_off_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppTheme.primaryDark, AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.84),
                    fontSize: 11.5,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          if (!hasDevices) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onAddDevice,
              tooltip: 'Add device',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryDark,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final _DashboardOverview overview;

  const _OverviewGrid({required this.overview});

  @override
  Widget build(BuildContext context) {
    final items = <_OverviewItem>[
      _OverviewItem(
        icon: Icons.wifi_rounded,
        color: Colors.green.shade700,
        label: 'Online',
        value: '${overview.onlineDevices}/${overview.totalDevices}',
      ),
      _OverviewItem(
        icon: Icons.power_settings_new_rounded,
        color: AppTheme.primary,
        label: 'Active now',
        value: '${overview.activeDevices}',
      ),
      _OverviewItem(
        icon: Icons.timer_outlined,
        color: Colors.orange.shade800,
        label: 'Timers',
        value: '${overview.activeTimers}',
      ),
      _OverviewItem(
        icon: Icons.schedule_rounded,
        color: Colors.deepPurple.shade600,
        label: 'Automations',
        value: '${overview.activeSchedules}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
              width: cardWidth,
              child: _OverviewStatCard(item: item),
            ),
          )
              .toList(),
        );
      },
    );
  }
}

class _OverviewItem {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _OverviewItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
}

class _OverviewStatCard extends StatelessWidget {
  final _OverviewItem item;

  const _OverviewStatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: item.color.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 13,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

class _DevicesSectionHeader extends StatelessWidget {
  final int deviceCount;
  final VoidCallback onAddDevice;

  const _DevicesSectionHeader({
    required this.deviceCount,
    required this.onAddDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your devices',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                deviceCount == 0
                    ? 'No device linked yet'
                    : '$deviceCount device${deviceCount == 1 ? '' : 's'} linked to your account',
                style: const TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onAddDevice,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Add',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DeviceOverviewCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onTap;

  const _DeviceOverviewCard({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final channel = device.channels['ch1'];
    final timer = device.timers['ch1'];
    final schedule = device.schedules['ch1'];

    final isOnline = device.isOnline;
    final isOn = channel?.state == true;
    final timerActive = timer?.enabled == true;
    final scheduleCount = schedule?.activeCount ?? 0;
    final isAutomationActive = scheduleCount > 0;

    final stateColor = !isOnline
        ? Colors.grey.shade600
        : isOn
        ? Colors.green.shade700
        : AppTheme.primary;

    final stateLabel = !isOnline
        ? 'Offline'
        : isOn
        ? 'ON'
        : 'OFF';

    final stateDetail = !isOnline
        ? 'Last seen ${device.lastSeenText}'
        : isOn
        ? 'Connected · Power is on'
        : 'Connected · Ready to control';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: stateColor.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isOn
                          ? Icons.lightbulb_rounded
                          : Icons.power_settings_new_rounded,
                      color: stateColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${device.model} · ${device.channelCount} channel${device.channelCount == 1 ? '' : 's'}',
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
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: stateColor,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatePill(label: stateLabel, color: stateColor),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      stateDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (timerActive || isAutomationActive) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (timerActive)
                      _DeviceTag(
                        icon: Icons.timer_outlined,
                        label: timer?.label.isNotEmpty == true
                            ? timer!.label
                            : 'Timer active',
                        color: Colors.orange.shade800,
                      ),
                    if (isAutomationActive)
                      _DeviceTag(
                        icon: Icons.schedule_rounded,
                        label: '$scheduleCount automation${scheduleCount == 1 ? '' : 's'}',
                        color: Colors.deepPurple.shade600,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 7,
            width: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DeviceTag({
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
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevicesCard extends StatelessWidget {
  final VoidCallback onAddDevice;

  const _EmptyDevicesCard({required this.onAddDevice});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.devices_other_rounded,
              color: AppTheme.primary,
              size: 31,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'No device linked yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your Easy Home Control device using its Device ID and claim code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddDevice,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add device',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAnotherDeviceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddAnotherDeviceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primary.withOpacity(0.16)),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add another device',
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _DashboardMessageCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12.5,
                    height: 1.3,
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
