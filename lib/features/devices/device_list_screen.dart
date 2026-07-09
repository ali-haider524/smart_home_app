import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';
import 'add_device_hub_screen.dart';
import 'device_control_screen.dart';
import 'device_settings_screen.dart';

/// Account-level device management entry point.
///
/// This reads the existing current-user mapping stream only. It does not alter
/// ownership, sharing, relay, Wi-Fi, timer or schedule behavior.
class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final DeviceService _deviceService = DeviceService();
  late final Stream<List<DeviceModel>> _devicesStream;

  @override
  void initState() {
    super.initState();
    _devicesStream = _deviceService.listenAllDevices();
  }

  Future<void> _openAddDevice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDeviceHubScreen()),
    );
  }

  Future<void> _openControl(DeviceModel device) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceControlScreen(
          deviceId: device.id,
          deviceName: device.nickname,
        ),
      ),
    );
  }

  Future<void> _openSettings(DeviceModel device) async {
    await Navigator.of(context).push<DeviceSettingsResult>(
      MaterialPageRoute(
        builder: (_) => DeviceSettingsScreen(
          deviceId: device.id,
          initialDeviceName: device.nickname,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Device management'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              tooltip: 'Add or join a device',
              onPressed: _openAddDevice,
              icon: const Icon(Icons.add_home_work_outlined),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<DeviceModel>>(
        stream: _devicesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _DeviceManagementMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load your devices',
              detail: 'Check your connection and return to this screen.',
              actionLabel: 'Back to Home',
              onAction: () => Navigator.of(context).pop(),
            );
          }

          final devices = snapshot.data ?? const <DeviceModel>[];

          if (devices.isEmpty) {
            return _DeviceManagementMessage(
              icon: Icons.add_home_work_outlined,
              title: 'No devices added yet',
              detail: 'Set up a new switch or join one shared with you.',
              actionLabel: 'Add or join a device',
              onAction: _openAddDevice,
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
            itemCount: devices.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _ManagementIntro();
              }

              final device = devices[index - 1];
              return _ManagedDeviceCard(
                device: device,
                onOpen: () => _openControl(device),
                onSettings: () => _openSettings(device),
              );
            },
          );
        },
      ),
    );
  }
}

class _ManagementIntro extends StatelessWidget {
  const _ManagementIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.tune_rounded, color: Colors.white, size: 25),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Open a device to control it. Use the settings icon to rename it, manage access, update Wi-Fi, or archive it.',
              style: TextStyle(
                color: Color(0xFFE7EFFF),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagedDeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onOpen;
  final VoidCallback onSettings;

  const _ManagedDeviceCard({
    required this.device,
    required this.onOpen,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final online = device.isOnline;
    final active = device.channels['ch1']?.state == true;
    final statusColor = online
        ? (active ? AppTheme.success : AppTheme.primary)
        : AppTheme.lightText;

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  active
                      ? Icons.power_settings_new_rounded
                      : Icons.lightbulb_outline_rounded,
                  color: statusColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
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
                    const SizedBox(height: 4),
                    Text(
                      online
                          ? (active ? 'Online • Power on' : 'Online • Power off')
                          : 'Offline • Last seen ${device.lastSeenText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Device settings',
                onPressed: onSettings,
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceManagementMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  const _DeviceManagementMessage({
    required this.icon,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppTheme.primary),
              const SizedBox(height: 14),
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
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
