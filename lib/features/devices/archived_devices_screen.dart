import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';

/// Reversible device removal. Archived devices are hidden from the active
/// dashboard but remain linked to the same user account and can be restored.
class ArchivedDevicesScreen extends StatefulWidget {
  const ArchivedDevicesScreen({super.key});

  @override
  State<ArchivedDevicesScreen> createState() => _ArchivedDevicesScreenState();
}

class _ArchivedDevicesScreenState extends State<ArchivedDevicesScreen> {
  final DeviceService _deviceService = DeviceService();
  String? _restoringId;

  Future<void> _restore(DeviceModel device) async {
    setState(() => _restoringId = device.id);

    try {
      await _deviceService.restoreArchivedDeviceForCurrentUser(
        deviceId: device.id,
      );
      if (!mounted) return;
      AppNotice.show(
        context,
        '${device.nickname} restored to My Devices.',
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
      if (mounted) setState(() => _restoringId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('Archived Devices'),
      ),
      body: StreamBuilder<List<DeviceModel>>(
        stream: _deviceService.listenArchivedDevices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _ArchiveMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load archived devices',
              subtitle: 'Check your connection and open this screen again.',
            );
          }

          final devices = snapshot.data ?? <DeviceModel>[];

          if (devices.isEmpty) {
            return const _ArchiveMessage(
              icon: Icons.inventory_2_outlined,
              title: 'No archived devices',
              subtitle: 'Devices removed from your dashboard will appear here and can be restored any time.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final device = devices[index];
              final restoring = _restoringId == device.id;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(7, 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.92),
                      blurRadius: 16,
                      offset: const Offset(-6, -6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: AppTheme.primary,
                      ),
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
                            style: const TextStyle(
                              color: AppTheme.darkText,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${device.id} • ${device.model}',
                            style: const TextStyle(
                              color: AppTheme.lightText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: restoring ? null : () => _restore(device),
                      icon: restoring
                          ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.unarchive_rounded, size: 18),
                      label: Text(restoring ? 'Restoring' : 'Restore'),
                    ),
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

class _ArchiveMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ArchiveMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
