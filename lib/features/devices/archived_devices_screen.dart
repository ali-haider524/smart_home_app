import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';

/// Archived devices are hidden from Home but remain linked to the same account.
/// Restoring a device only returns its existing shortcut to My Devices.
class ArchivedDevicesScreen extends StatefulWidget {
  const ArchivedDevicesScreen({super.key});

  @override
  State<ArchivedDevicesScreen> createState() => _ArchivedDevicesScreenState();
}

class _ArchivedDevicesScreenState extends State<ArchivedDevicesScreen> {
  final DeviceService _deviceService = DeviceService();

  late Stream<List<DeviceModel>> _archivedDevicesStream;
  String? _restoringId;

  @override
  void initState() {
    super.initState();
    _archivedDevicesStream = _deviceService.listenArchivedDevices();
  }

  void _reload() {
    setState(() {
      _archivedDevicesStream = _deviceService.listenArchivedDevices();
    });
  }

  Future<void> _restore(DeviceModel device) async {
    if (_restoringId != null) {
      return;
    }

    setState(() => _restoringId = device.id);

    try {
      await _deviceService.restoreArchivedDeviceForCurrentUser(
        deviceId: device.id,
      );

      if (!mounted) return;

      AppNotice.show(
        context,
        '${device.nickname} is back in My Devices.',
        type: AppNoticeType.success,
      );
    } on DeviceMaintenanceException catch (error) {
      if (!mounted) return;
      AppNotice.show(context, error.message, type: AppNoticeType.error);
    } catch (_) {
      if (!mounted) return;
      AppNotice.show(
        context,
        'Could not restore this device. Please try again.',
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _restoringId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: AppTheme.background,
        elevation: 0,
        title: const Text('Archived devices'),
      ),
      body: StreamBuilder<List<DeviceModel>>(
        stream: _archivedDevicesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ArchiveFeedbackState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load archived devices',
              subtitle:
              'Check your connection, then try loading this page again.',
              actionLabel: 'Try again',
              onAction: _reload,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _ArchiveLoadingState();
          }

          final devices = snapshot.data ?? const <DeviceModel>[];

          if (devices.isEmpty) {
            return const _ArchiveFeedbackState(
              icon: Icons.inventory_2_outlined,
              title: 'No archived devices',
              subtitle:
              'Devices you remove from Home stay safely here until you restore them.',
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
            children: [
              _ArchivedIntro(count: devices.length),
              const SizedBox(height: 16),
              ...devices.map(
                    (device) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ArchivedDeviceCard(
                    device: device,
                    restoring: _restoringId == device.id,
                    onRestore: () => _restore(device),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const _ArchiveSafetyNote(),
            ],
          );
        },
      ),
    );
  }
}

class _ArchivedIntro extends StatelessWidget {
  final int count;

  const _ArchivedIntro({required this.count});

  @override
  Widget build(BuildContext context) {
    final deviceLabel = count == 1 ? 'device' : 'devices';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.primaryDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count archived $deviceLabel',
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Restore a device whenever you want it back on Home.',
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
      ),
    );
  }
}

class _ArchivedDeviceCard extends StatelessWidget {
  final DeviceModel device;
  final bool restoring;
  final VoidCallback onRestore;

  const _ArchivedDeviceCard({
    required this.device,
    required this.restoring,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = device.isOnline ? AppTheme.success : AppTheme.lightText;
    final statusText = device.isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.power_outlined,
                  color: AppTheme.primaryDark,
                  size: 23,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${device.model} • ${device.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DeviceStatusChip(
                label: statusText,
                color: statusColor,
                icon: device.isOnline
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  device.isOnline
                      ? 'Device is available to restore.'
                      : 'Last seen ${device.lastSeenText}.',
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 42,
                child: FilledButton.icon(
                  onPressed: restoring ? null : onRestore,
                  icon: restoring
                      ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.unarchive_rounded, size: 18),
                  label: Text(restoring ? 'Restoring' : 'Restore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _DeviceStatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveSafetyNote extends StatelessWidget {
  const _ArchiveSafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primaryDark,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Archiving does not erase the device, its Wi-Fi setup, timers, or schedules. It only hides it from your Home screen.',
              style: TextStyle(
                color: AppTheme.lightText,
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

class _ArchiveLoadingState extends StatelessWidget {
  const _ArchiveLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _ArchiveFeedbackState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ArchiveFeedbackState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 29, color: AppTheme.primaryDark),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
