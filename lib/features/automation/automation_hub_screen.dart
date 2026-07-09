import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_theme.dart';
import '../../core/tech_surface.dart';
import '../../models/device_model.dart';
import '../../models/schedule_model.dart';
import '../../models/timer_model.dart';
import '../../services/app_ticker.dart';
import '../../services/device_service.dart';
import '../devices/device_control_screen.dart';

/// Read-only automation overview.
///
/// This screen only reads timer and schedule data, then opens the already
/// tested DeviceControlScreen when the user wants to change anything. Timer
/// writes, schedule writes, Firebase paths, and ESP behaviour stay in the
/// existing device-control flow.
class AutomationHubScreen extends StatefulWidget {
  const AutomationHubScreen({super.key});

  @override
  State<AutomationHubScreen> createState() => _AutomationHubScreenState();
}

class _AutomationHubScreenState extends State<AutomationHubScreen> {
  final DeviceService _deviceService = DeviceService();
  late final Stream<List<DeviceModel>> _activeDevicesStream;

  @override
  void initState() {
    super.initState();
    // Only devices linked to the signed-in user are read.
    _activeDevicesStream = _deviceService.listenAllDevices();
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

  Future<void> _chooseDevice(List<DeviceModel> devices) async {
    if (devices.isEmpty) return;

    if (devices.length == 1) {
      _openDevice(devices.first);
      return;
    }

    final selected = await showModalBottomSheet<DeviceModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DevicePickerSheet(devices: devices),
    );

    if (!mounted || selected == null) return;
    _openDevice(selected);
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
                final overview = _AutomationOverview.fromDevices(devices);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _AutomationHeader(
                          title: context.tr('Automation'),
                          subtitle: _headerSubtitle(context, overview),
                        ),
                      ),
                    ),
                    if (deviceSnapshot.hasError)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
                        sliver: SliverToBoxAdapter(
                          child: _MessageCard(
                            icon: Icons.cloud_off_rounded,
                            title: context.tr('Could not load automations'),
                            detail: context.tr(
                              'Check your internet connection, then return to this screen.',
                            ),
                          ),
                        ),
                      )
                    else if (deviceSnapshot.connectionState ==
                        ConnectionState.waiting &&
                        !deviceSnapshot.hasData)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 72),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (devices.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
                          sliver: SliverToBoxAdapter(
                            child: _MessageCard(
                              icon: Icons.auto_awesome_outlined,
                              title: context.tr('No devices linked yet'),
                              detail: context.tr(
                                'Add a smart switch from the Home tab, then its timers and schedules will appear here.',
                              ),
                            ),
                          ),
                        )
                      else ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            sliver: SliverToBoxAdapter(
                              child: _AutomationCounts(overview: overview),
                            ),
                          ),
                          if (overview.totalEnabled == 0)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
                              sliver: SliverToBoxAdapter(
                                child: _AutomationSetupCard(
                                  hasAutomation: false,
                                  onTap: () {
                                    _chooseDevice(devices);
                                  },
                                ),
                              ),
                            )
                          else ...[
                            if (overview.timers.isNotEmpty) ...[
                              SliverPadding(
                                padding:
                                const EdgeInsets.fromLTRB(20, 28, 20, 12),
                                sliver: SliverToBoxAdapter(
                                  child: _SectionHeader(
                                    icon: Icons.timer_outlined,
                                    title: context.tr('Running timers'),
                                    detail:
                                    '${overview.timers.length} ${context.tr('active now')}',
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                      final itemIndex = index ~/ 2;
                                      if (index.isOdd) {
                                        return const SizedBox(height: 10);
                                      }

                                      final timer = overview.timers[itemIndex];
                                      return _TimerAutomationCard(
                                        timer: timer,
                                        onTap: () => _openDevice(timer.device),
                                      );
                                    },
                                    childCount: overview.timers.length == 1
                                        ? 1
                                        : (overview.timers.length * 2) - 1,
                                  ),
                                ),
                              ),
                            ],
                            if (overview.schedules.isNotEmpty) ...[
                              SliverPadding(
                                padding:
                                const EdgeInsets.fromLTRB(20, 28, 20, 12),
                                sliver: SliverToBoxAdapter(
                                  child: _SectionHeader(
                                    icon: Icons.calendar_month_outlined,
                                    title: context.tr('Weekly schedules'),
                                    detail:
                                    '${overview.schedules.length} ${context.tr('Enabled')}',
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                      final itemIndex = index ~/ 2;
                                      if (index.isOdd) {
                                        return const SizedBox(height: 10);
                                      }

                                      final schedule =
                                      overview.schedules[itemIndex];
                                      return _ScheduleAutomationCard(
                                        schedule: schedule,
                                        onTap: () => _openDevice(schedule.device),
                                      );
                                    },
                                    childCount: overview.schedules.length == 1
                                        ? 1
                                        : (overview.schedules.length * 2) - 1,
                                  ),
                                ),
                              ),
                            ],
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
                              sliver: SliverToBoxAdapter(
                                child: _AutomationSetupCard(
                                  hasAutomation: true,
                                  onTap: () {
                                    _chooseDevice(devices);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _headerSubtitle(
      BuildContext context,
      _AutomationOverview overview,
      ) {
    if (overview.totalDevices == 0) {
      return context.tr(
        'Timers and schedules will appear here after you add a device.',
      );
    }

    if (overview.totalEnabled == 0) {
      return context.tr('Keep your home running on time.');
    }

    final parts = <String>[];
    if (overview.timers.isNotEmpty) {
      parts.add(
        '${overview.timers.length} ${context.tr('timer')}${overview.timers.length == 1 ? '' : 's'}',
      );
    }
    if (overview.schedules.isNotEmpty) {
      parts.add(
        '${overview.schedules.length} ${context.tr('schedule')}${overview.schedules.length == 1 ? '' : 's'}',
      );
    }

    return '${parts.join(' · ')} ${context.tr('across your linked devices')}.';
  }
}

class _AutomationOverview {
  final int totalDevices;
  final List<_TimerAutomation> timers;
  final List<_ScheduleAutomation> schedules;

  const _AutomationOverview({
    required this.totalDevices,
    required this.timers,
    required this.schedules,
  });

  int get totalEnabled => timers.length + schedules.length;

  factory _AutomationOverview.fromDevices(List<DeviceModel> devices) {
    final timers = <_TimerAutomation>[];
    final schedules = <_ScheduleAutomation>[];

    for (final device in devices) {
      device.timers.forEach((channelId, timer) {
        if (timer.enabled) {
          timers.add(
            _TimerAutomation(
              device: device,
              channelId: channelId,
              timer: timer,
            ),
          );
        }
      });

      device.schedules.forEach((channelId, scheduleModel) {
        for (final schedule in scheduleModel.activeItems) {
          schedules.add(
            _ScheduleAutomation(
              device: device,
              channelId: channelId,
              schedule: schedule,
            ),
          );
        }
      });
    }

    timers.sort(
          (left, right) => left.device.nickname.compareTo(right.device.nickname),
    );
    schedules.sort((left, right) {
      final deviceCompare =
      left.device.nickname.compareTo(right.device.nickname);
      if (deviceCompare != 0) return deviceCompare;
      return left.schedule.onMinutes.compareTo(right.schedule.onMinutes);
    });

    return _AutomationOverview(
      totalDevices: devices.length,
      timers: timers,
      schedules: schedules,
    );
  }
}

class _TimerAutomation {
  final DeviceModel device;
  final String channelId;
  final TimerModel timer;

  const _TimerAutomation({
    required this.device,
    required this.channelId,
    required this.timer,
  });

  String get channelLabel => _channelName(channelId);

  String get title {
    final label = timer.label.trim();
    return label.isEmpty ? '${_formatDuration(timer.durationMs)} timer' : label;
  }

  String get detail => 'Turns off after ${_formatDuration(timer.durationMs)}';
}

class _ScheduleAutomation {
  final DeviceModel device;
  final String channelId;
  final ScheduleItem schedule;

  const _ScheduleAutomation({
    required this.device,
    required this.channelId,
    required this.schedule,
  });

  String get channelLabel => _channelName(channelId);
}

class _AutomationHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AutomationHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return TechHeroSurface(
      padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
      colors: const [
        Color(0xFF33246F),
        AppTheme.automation,
        AppTheme.primary,
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EASY HOME CONTROL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.77),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.77),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationCounts extends StatelessWidget {
  final _AutomationOverview overview;

  const _AutomationCounts({required this.overview});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CountCard(
            icon: Icons.timer_outlined,
            iconColor: AppTheme.warning,
            label: context.tr('Timers'),
            value: overview.timers.length.toString(),
            detail: overview.timers.isEmpty
                ? context.tr('None running')
                : context.tr('Running now'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CountCard(
            icon: Icons.calendar_month_outlined,
            iconColor: AppTheme.automation,
            label: context.tr('Schedules'),
            value: overview.schedules.length.toString(),
            detail: overview.schedules.isEmpty
                ? context.tr('None enabled')
                : context.tr('Enabled'),
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String detail;

  const _CountCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _softCardDecoration(),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: AppTheme.primaryDark),
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
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimerAutomationCard extends StatelessWidget {
  final _TimerAutomation timer;
  final VoidCallback onTap;

  const _TimerAutomationCard({
    required this.timer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _AutomationItemCard(
      icon: Icons.timer_outlined,
      iconColor: AppTheme.warning,
      title: timer.title,
      subtitle: '${timer.device.nickname} · ${timer.channelLabel}',
      detail: timer.detail,
      actionLabel: context.tr('Manage'),
      onTap: onTap,
    );
  }
}

class _ScheduleAutomationCard extends StatelessWidget {
  final _ScheduleAutomation schedule;
  final VoidCallback onTap;

  const _ScheduleAutomationCard({
    required this.schedule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = schedule.schedule;

    return _AutomationItemCard(
      icon: Icons.calendar_month_outlined,
      iconColor: AppTheme.automation,
      title: item.label,
      subtitle: '${schedule.device.nickname} · ${schedule.channelLabel}',
      detail:
      '${_formatClock(item.onMinutes)} on  →  ${_formatClock(item.offMinutes)} off · ${item.daysSummary}',
      actionLabel: context.tr('Manage'),
      onTap: onTap,
    );
  }
}

class _AutomationItemCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String detail;
  final String actionLabel;
  final VoidCallback onTap;

  const _AutomationItemCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.detail,
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
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: iconColor.withOpacity(0.16)),
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
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutomationSetupCard extends StatelessWidget {
  final bool hasAutomation;
  final VoidCallback onTap;

  const _AutomationSetupCard({
    required this.hasAutomation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = hasAutomation
        ? context.tr('Set up more automation')
        : context.tr('Set up your routine');

    final detail = hasAutomation
        ? context.tr('Choose a device to add another timer or weekly schedule.')
        : context.tr(
      'Use a device control screen to create your first timer or schedule.',
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _softCardDecoration(
        borderColor: AppTheme.primary.withOpacity(0.14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_alarm_outlined,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 12,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.devices_other_outlined),
              label: Text(context.tr('Choose device')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _softCardDecoration(),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 29),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicePickerSheet extends StatelessWidget {
  final List<DeviceModel> devices;

  const _DevicePickerSheet({required this.devices});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 46,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.16),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'Choose a device',
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Open a device to set when its switch should turn on and off.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return _DevicePickerRow(
                    device: device,
                    onTap: () => Navigator.pop(context, device),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicePickerRow extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onTap;

  const _DevicePickerRow({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = device.isOnline ? AppTheme.success : AppTheme.lightText;

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.outline),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.power_outlined,
                  color: AppTheme.primaryDark,
                  size: 22,
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
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${device.model} · ${device.channelCount} ${device.channelCount == 1 ? 'switch' : 'switches'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  device.isOnline
                      ? context.tr('Online')
                      : context.tr('Offline'),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.primary,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _softCardDecoration({Color? borderColor}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.card,
        AppTheme.primary.withValues(alpha: 0.025),
      ],
    ),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: borderColor ?? AppTheme.primary.withValues(alpha: 0.13),
    ),
    boxShadow: [
      BoxShadow(
        color: AppTheme.primary.withValues(alpha: 0.045),
        blurRadius: 15,
        offset: const Offset(0, 7),
      ),
    ],
  );
}

String _channelName(String channelId) {
  final normalized = channelId.trim().toLowerCase();
  if (normalized == 'ch1') return 'Switch 1';
  if (normalized.startsWith('ch')) {
    final number = normalized.substring(2);
    if (number.isNotEmpty) return 'Switch $number';
  }
  return channelId.trim().isEmpty ? 'Switch' : channelId.trim();
}

String _formatDuration(int durationMs) {
  if (durationMs <= 0) return 'a short time';

  final totalMinutes = durationMs ~/ (60 * 1000);
  if (totalMinutes <= 0) return 'less than a minute';

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) return '$totalMinutes min';
  if (minutes == 0) return '$hours hr';
  return '$hours hr $minutes min';
}

String _formatClock(int totalMinutes) {
  final clamped = totalMinutes.clamp(0, 1439).toInt();
  final hour24 = clamped ~/ 60;
  final minute = clamped % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minuteText = minute.toString().padLeft(2, '0');

  return '$hour12:$minuteText $period';
}
