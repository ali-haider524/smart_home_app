import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../core/tech_surface.dart';
import '../../models/device_model.dart';
import '../../services/app_ticker.dart';
import '../../services/device_service.dart';
import '../settings/app_settings_screen.dart';
import 'add_device_hub_screen.dart';
import 'archived_devices_screen.dart';
import 'device_control_screen.dart';

/// The main home view reads existing device streams and opens the existing
/// device, archive, pairing and settings screens. This UI pass does not change
/// Firebase paths, commands, pairing, timers, schedules or Wi-Fi behaviour.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _dashboardChannelId = 'ch1';
  static const Duration _quickPowerConfirmationTimeout = Duration(seconds: 15);

  final DeviceService _deviceService = DeviceService();
  late final Stream<List<DeviceModel>> _devicesStream;
  late final Stream<List<DeviceModel>> _archivedDevicesStream;

  // The dashboard keeps its own lightweight command state per device. It only
  // sends the existing /command payload and waits for the ESP-reported /state;
  // it never changes the UI optimistically or writes relay state directly.
  final Map<String, _DashboardPowerCommand> _quickPowerCommands =
  <String, _DashboardPowerCommand>{};
  int _quickPowerAttempt = 0;

  @override
  void initState() {
    super.initState();
    _devicesStream = _deviceService.listenAllDevices();
    _archivedDevicesStream = _deviceService.listenArchivedDevices();
  }

  @override
  void dispose() {
    for (final command in _quickPowerCommands.values) {
      command.timeout?.cancel();
    }
    _quickPowerCommands.clear();
    super.dispose();
  }

  void _openAddDevice() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDeviceHubScreen()),
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

  void _openArchivedDevices() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArchivedDevicesScreen()),
    );
  }

  void _openProfileAndSettings() {
    // AppSettingsScreen is normally displayed inside HomeShell. When opened
    // from the profile shortcut, it needs an opaque page behind it so Android
    // never shows a transparent or black route during the transition.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppTheme.background,
          body: AppSettingsScreen(),
        ),
      ),
    );
  }

  Future<void> _sendQuickPowerCommand(DeviceModel device) async {
    final channel = device.channels[_dashboardChannelId];

    // A dashboard card must never create a command for an unknown channel or
    // send another command while confirmation for this device is still pending.
    if (channel == null || !device.isOnline || _quickPowerCommands.containsKey(device.id)) {
      return;
    }

    final requestedState = !channel.state;
    final attempt = ++_quickPowerAttempt;

    setState(() {
      _quickPowerCommands[device.id] = _DashboardPowerCommand(
        attempt: attempt,
        requestedState: requestedState,
      );
    });

    try {
      await _deviceService.setChannelState(
        deviceId: device.id,
        channelId: _dashboardChannelId,
        state: requestedState,
      );

      // The ESP can confirm before the Firebase write Future returns. Do not
      // attach an obsolete timer in that case.
      if (!mounted) {
        return;
      }

      final pending = _quickPowerCommands[device.id];
      if (pending == null || pending.attempt != attempt) {
        return;
      }

      pending.timeout?.cancel();
      pending.timeout = Timer(_quickPowerConfirmationTimeout, () {
        if (!mounted) {
          return;
        }

        final current = _quickPowerCommands[device.id];
        if (current == null || current.attempt != attempt) {
          return;
        }

        _clearQuickPowerCommand(device.id);
        AppNotice.show(
          context,
          context.tr(
            'The switch did not confirm this command. Check its connection and current state before trying again.',
          ),
          type: AppNoticeType.error,
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      final current = _quickPowerCommands[device.id];
      if (current == null || current.attempt != attempt) {
        return;
      }

      _clearQuickPowerCommand(device.id);
      AppNotice.show(
        context,
        context.tr(
          'Could not send the command. Check your internet connection and try again.',
        ),
        type: AppNoticeType.error,
      );
    }
  }

  void _queueQuickPowerConfirmation(DeviceModel device) {
    final pending = _quickPowerCommands[device.id];
    final actualState = device.channels[_dashboardChannelId]?.state;

    if (pending == null) {
      return;
    }

    if (actualState == null || pending.requestedState != actualState) {
      // A newer device update can arrive before the queued post-frame check.
      // Let a later matching ESP state schedule its own confirmation.
      pending.confirmationQueued = false;
      return;
    }

    if (pending.confirmationQueued) {
      return;
    }

    pending.confirmationQueued = true;
    final attempt = pending.attempt;

    // Device state arrives through a StreamBuilder. Confirm after this build so
    // the dashboard never calls setState while its widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final current = _quickPowerCommands[device.id];
      if (current == null ||
          current.attempt != attempt ||
          current.requestedState != actualState) {
        return;
      }

      _clearQuickPowerCommand(device.id);
      AppNotice.show(
        context,
        actualState
            ? context.tr('Switch turned ON.')
            : context.tr('Switch turned OFF.'),
        type: AppNoticeType.success,
      );
    });
  }

  void _clearQuickPowerCommand(String deviceId) {
    final pending = _quickPowerCommands.remove(deviceId);
    pending?.timeout?.cancel();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<DeviceModel>>(
          stream: _devicesStream,
          builder: (context, deviceSnapshot) {
            return StreamBuilder<List<DeviceModel>>(
              stream: _archivedDevicesStream,
              builder: (context, archivedSnapshot) {
                return StreamBuilder<DateTime>(
                  stream: AppTicker.instance.stream,
                  builder: (context, _) {
                    final devices =
                        deviceSnapshot.data ?? const <DeviceModel>[];
                    final archivedCount = archivedSnapshot.data?.length ?? 0;
                    final overview = _HomeOverview.fromDevices(devices);

                    for (final device in devices) {
                      _queueQuickPowerConfirmation(device);
                    }

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
                          sliver: SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                const BoxConstraints(maxWidth: 680),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _HomeHeader(
                                      greeting: context.tr(_greetingText()),
                                      subtitle:
                                      _headerSubtitle(context, overview),
                                      archivedCount: archivedCount,
                                      profileInitial: _profileInitial(),
                                      onOpenArchived: _openArchivedDevices,
                                      onOpenProfile: _openProfileAndSettings,
                                    ),
                                    const SizedBox(height: 24),
                                    if (deviceSnapshot.hasError) ...[
                                      _LoadErrorCard(
                                        onRetry: () => setState(() {}),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    _QuickStatusRow(overview: overview),
                                    const SizedBox(height: 28),
                                    _SectionHeader(
                                      title: context.tr('Your devices'),
                                      subtitle:
                                      context.l10n.devices(devices.length),
                                      actionLabel: devices.isEmpty
                                          ? null
                                          : context.tr('Add device'),
                                      onAction: devices.isEmpty
                                          ? null
                                          : _openAddDevice,
                                    ),
                                    const SizedBox(height: 12),
                                    if (devices.isEmpty)
                                      _EmptyHomeCard(
                                        onAddDevice: _openAddDevice,
                                      )
                                    else
                                      for (var index = 0;
                                      index < devices.length;
                                      index++) ...[
                                        _DeviceCard(
                                          device: devices[index],
                                          commandPending: _quickPowerCommands
                                              .containsKey(devices[index].id),
                                          requestedState: _quickPowerCommands[
                                          devices[index].id]
                                              ?.requestedState,
                                          onTap: () =>
                                              _openDevice(devices[index]),
                                          onQuickPowerTap: devices[index].isOnline &&
                                              devices[index]
                                                  .channels
                                                  .containsKey(_dashboardChannelId) &&
                                              !_quickPowerCommands.containsKey(
                                                devices[index].id,
                                              )
                                              ? () => _sendQuickPowerCommand(
                                            devices[index],
                                          )
                                              : null,
                                        ),
                                        if (index != devices.length - 1)
                                          const SizedBox(height: 12),
                                      ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _headerSubtitle(BuildContext context, _HomeOverview overview) {
    if (overview.total == 0) {
      return context.tr('Add your first smart switch to get started.');
    }

    if (overview.online == 0) {
      return context.tr('Check power and Wi-Fi');
    }

    return context.l10n.activeNow(overview.active);
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _profileInitial() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();
    final phone = (user?.phoneNumber ?? '').trim();
    final source = displayName.isNotEmpty
        ? displayName
        : (email.isNotEmpty ? email : (phone.isNotEmpty ? phone : 'U'));

    return source.substring(0, 1).toUpperCase();
  }
}

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String subtitle;
  final int archivedCount;
  final String profileInitial;
  final VoidCallback onOpenArchived;
  final VoidCallback onOpenProfile;

  const _HomeHeader({
    required this.greeting,
    required this.subtitle,
    required this.archivedCount,
    required this.profileInitial,
    required this.onOpenArchived,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return TechHeroSurface(
      padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Easy Home Control',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.75,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Smart home control',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              _HeaderArchiveButton(
                count: archivedCount,
                onTap: onOpenArchived,
              ),
              const SizedBox(height: 8),
              _ProfileButton(
                initial: profileInitial,
                onTap: onOpenProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderArchiveButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _HeaderArchiveButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final semanticLabel = count > 0
        ? '$count archived device${count == 1 ? '' : 's'}'
        : 'Archived devices';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0C3A98).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06266B).withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.electric,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppTheme.primaryDark,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final String initial;
  final VoidCallback onTap;

  const _ProfileButton({required this.initial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profile and settings',
      child: Tooltip(
        message: 'Profile and settings',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Ink(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF062C7D).withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.48),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06266B).withValues(alpha: 0.34),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small status cards give an at-a-glance summary without turning the home
/// screen into a long dashboard. They are calculated from existing device data.
class _QuickStatusRow extends StatelessWidget {
  final _HomeOverview overview;

  const _QuickStatusRow({required this.overview});

  @override
  Widget build(BuildContext context) {
    final hasOnlineDevice = overview.online > 0;

    return Row(
      children: [
        Expanded(
          child: _StatusTile(
            icon: hasOnlineDevice
                ? Icons.wifi_rounded
                : Icons.wifi_off_rounded,
            value: '${overview.online}/${overview.total}',
            label: context.tr('Online'),
            color: hasOnlineDevice ? AppTheme.success : AppTheme.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusTile(
            icon: Icons.power_rounded,
            value: overview.active.toString(),
            label: context.tr('ON'),
            color: overview.active > 0 ? AppTheme.success : AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusTile(
            icon: Icons.schedule_rounded,
            value: overview.automationCount.toString(),
            label: context.tr('Auto'),
            color: AppTheme.automation,
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatusTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.card,
            color.withValues(alpha: 0.055),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 29,
            width: 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.09),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.13)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
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
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final bool commandPending;
  final bool? requestedState;
  final VoidCallback onTap;
  final VoidCallback? onQuickPowerTap;

  const _DeviceCard({
    required this.device,
    required this.commandPending,
    required this.requestedState,
    required this.onTap,
    required this.onQuickPowerTap,
  });

  @override
  Widget build(BuildContext context) {
    final channel = device.channels['ch1'];
    final isOnline = device.isOnline;
    final isOn = channel?.state == true;
    final timerActive = device.timers['ch1']?.enabled == true;
    final scheduleCount = device.schedules['ch1']?.activeCount ?? 0;

    final accent = !isOnline
        ? const Color(0xFF7C879B)
        : isOn
        ? AppTheme.success
        : AppTheme.primary;
    final statusText = !isOnline
        ? '${context.tr('Offline')} · ${device.lastSeenText}'
        : isOn
        ? context.tr('ON')
        : context.tr('OFF');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.card,
                accent.withValues(alpha: 0.045),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.055),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _QuickPowerControl(
                isOnline: isOnline,
                isOn: isOn,
                commandPending: commandPending,
                requestedState: requestedState,
                onTap: onQuickPowerTap,
              ),
              const SizedBox(width: 14),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${device.model} · ${device.channelCount} ch',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _DeviceStatusPill(
                          icon: !isOnline
                              ? Icons.wifi_off_rounded
                              : isOn
                              ? Icons.power_rounded
                              : Icons.power_outlined,
                          text: statusText,
                          color: accent,
                        ),
                        if (timerActive)
                          _DeviceStatusPill(
                            icon: Icons.timer_outlined,
                            text: context.tr('Timer active'),
                            color: AppTheme.warning,
                          ),
                        if (scheduleCount > 0)
                          _DeviceStatusPill(
                            icon: Icons.schedule_rounded,
                            text: context.l10n.scheduleCount(scheduleCount),
                            color: AppTheme.automation,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const _CardChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardPowerCommand {
  final int attempt;
  final bool requestedState;
  Timer? timeout;
  bool confirmationQueued = false;

  _DashboardPowerCommand({
    required this.attempt,
    required this.requestedState,
  });
}
class _QuickPowerControl extends StatelessWidget {
  final bool isOnline;
  final bool isOn;
  final bool commandPending;
  final bool? requestedState;
  final VoidCallback? onTap;

  const _QuickPowerControl({
    required this.isOnline,
    required this.isOn,
    required this.commandPending,
    required this.requestedState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = !isOnline
        ? context.tr('Offline')
        : commandPending
        ? context.tr('Sending')
        : context.tr('Power');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuickPowerButton(
          isOnline: isOnline,
          isOn: isOn,
          commandPending: commandPending,
          requestedState: requestedState,
          onTap: onTap,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: !isOnline ? const Color(0xFF97A1B2) : AppTheme.lightText,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _CardChevron extends StatelessWidget {
  const _CardChevron();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.lightText.withValues(alpha: 0.85),
        size: 23,
      ),
    );
  }
}

class _QuickPowerButton extends StatelessWidget {
  final bool isOnline;
  final bool isOn;
  final bool commandPending;
  final bool? requestedState;
  final VoidCallback? onTap;

  const _QuickPowerButton({
    required this.isOnline,
    required this.isOn,
    required this.commandPending,
    required this.requestedState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final accent = !isOnline
        ? const Color(0xFF99A2B2)
        : isOn
        ? AppTheme.success
        : AppTheme.primary;
    final requestedLabel = requestedState == true
        ? context.tr('ON')
        : context.tr('OFF');
    final semanticLabel = commandPending
        ? '${context.tr('Sending')} $requestedLabel ${context.tr('command')}'
        : !isOnline
        ? context.tr('Device is offline')
        : isOn
        ? context.tr('Turn switch off')
        : context.tr('Turn switch on');
    final tooltip = commandPending
        ? '${context.tr('Sending')} $requestedLabel'
        : semanticLabel;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isEnabled
                      ? isOn
                      ? [
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.12),
                  ]
                      : [
                    Colors.white,
                    accent.withValues(alpha: 0.09),
                  ]
                      : [
                    const Color(0xFFF3F5F8),
                    const Color(0xFFEDEFF4),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: isEnabled ? 0.34 : 0.16),
                  width: isOn ? 2.0 : 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: isEnabled ? 0.12 : 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: isEnabled ? 0.18 : 0.10),
                        width: 1.2,
                      ),
                    ),
                  ),
                  if (!isOnline)
                    Icon(
                      Icons.power_settings_new_rounded,
                      color: accent.withValues(alpha: 0.55),
                      size: 28,
                    )
                  else if (commandPending)
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: accent,
                      ),
                    )
                  else
                    Icon(
                      Icons.power_settings_new_rounded,
                      color: accent.withValues(alpha: isEnabled ? 1 : 0.58),
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  final bool isOnline;
  final bool isOn;
  final Color accent;

  const _DeviceIcon({
    required this.isOnline,
    required this.isOn,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 50,
          width: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.45, -0.5),
              colors: [
                accent.withValues(alpha: 0.24),
                accent.withValues(alpha: 0.09),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: Icon(
            isOn ? Icons.lightbulb_rounded : Icons.power_rounded,
            color: accent,
            size: 24,
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            height: 14,
            width: 14,
            decoration: BoxDecoration(
              color: isOnline ? AppTheme.success : const Color(0xFF8B95A7),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.card, width: 3),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceStatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _DeviceStatusPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 158),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 124),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact inline empty state keeps the dashboard useful without showing a
/// large full-screen button. While empty, this is the only Add Device action.
class _EmptyHomeCard extends StatelessWidget {
  final VoidCallback onAddDevice;

  const _EmptyHomeCard({required this.onAddDevice});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_home_outlined,
              color: AppTheme.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('No devices yet'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr('Add your first smart switch to get started.'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 11.5,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onAddDevice,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: Text(context.tr('Add')),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('Could not load devices'),
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(context.tr('Retry')),
          ),
        ],
      ),
    );
  }
}

class _HomeOverview {
  final int total;
  final int online;
  final int active;
  final int timerCount;
  final int scheduleCount;

  const _HomeOverview({
    required this.total,
    required this.online,
    required this.active,
    required this.timerCount,
    required this.scheduleCount,
  });

  int get automationCount => timerCount + scheduleCount;

  factory _HomeOverview.fromDevices(List<DeviceModel> devices) {
    var online = 0;
    var active = 0;
    var timers = 0;
    var schedules = 0;

    for (final device in devices) {
      if (device.isOnline) online++;
      if (device.channels['ch1']?.state == true) active++;
      if (device.timers['ch1']?.enabled == true) timers++;
      schedules += device.schedules['ch1']?.activeCount ?? 0;
    }

    return _HomeOverview(
      total: devices.length,
      online: online,
      active: active,
      timerCount: timers,
      scheduleCount: schedules,
    );
  }
}
