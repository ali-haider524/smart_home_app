import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';

/// Returned to DeviceControlScreen after settings changes.
class DeviceSettingsResult {
  final String? nickname;
  final bool removed;
  final bool openWiFiSetup;

  const DeviceSettingsResult({
    this.nickname,
    this.removed = false,
    this.openWiFiSetup = false,
  });
}

/// Safe per-device settings.
///
/// It deliberately does not write to command/state/timer/schedule paths.
/// WiFi reset uses the separate maintenance/resetWifi contract handled by
/// firmware v1.4.0 after it acknowledges the request.
class DeviceSettingsScreen extends StatefulWidget {
  final String deviceId;
  final String initialDeviceName;

  const DeviceSettingsScreen({
    super.key,
    required this.deviceId,
    required this.initialDeviceName,
  });

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final DeviceService _deviceService = DeviceService();
  late String _deviceName;
  late final Stream<DeviceModel?> _deviceStream;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _deviceName = widget.initialDeviceName.trim().isEmpty
        ? 'Smart Switch'
        : widget.initialDeviceName.trim();
    _deviceStream = _deviceService.listenDevice(widget.deviceId);
  }

  void _close() {
    Navigator.pop(
      context,
      DeviceSettingsResult(nickname: _deviceName),
    );
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  Future<void> _renameDevice() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDeviceDialog(initialName: _deviceName),
    );

    if (!mounted || newName == null || newName == _deviceName) {
      return;
    }

    setState(() => _busy = true);

    try {
      await _deviceService.renameDeviceForCurrentUser(
        deviceId: widget.deviceId,
        nickname: newName,
      );

      if (!mounted) return;
      setState(() => _deviceName = newName);
      _showMessage('Device renamed');
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not rename the device. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changeWiFi({required bool online}) async {
    if (!online) {
      _showMessage('Device must be online before WiFi can be changed.');
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ConfirmWifiResetSheet(
          onCancel: () => Navigator.pop(sheetContext, false),
          onConfirm: () => Navigator.pop(sheetContext, true),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    var openingWiFiSetup = false;

    try {
      final requestId = await _deviceService.requestWiFiReset(
        deviceId: widget.deviceId,
      );

      if (!mounted) return;

      final acknowledged = await _deviceService.waitForWiFiResetAcknowledgement(
        deviceId: widget.deviceId,
        requestId: requestId,
      );

      if (!mounted) return;

      if (!acknowledged) {
        await _showWiFiResetTimeoutDialog();
        return;
      }

      // Return the hand-off result to DeviceControlScreen. It owns the next
      // navigation step, avoiding route replacement while this page's stream
      // widgets are being disposed.
      openingWiFiSetup = true;
      setState(() => _busy = false);
      if (!mounted) return;

      Navigator.pop(
        context,
        DeviceSettingsResult(
          nickname: _deviceName,
          openWiFiSetup: true,
        ),
      );
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
        'WiFi reset request failed. Check the device connection and try again.',
      );
    } finally {
      if (mounted && !openingWiFiSetup) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showWiFiResetTimeoutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Device did not confirm yet'),
          content: const Text(
            'The reset request was sent, but the app did not receive an acknowledgement. '
                'The device may be offline. Do not send repeated requests. Check the device is online and try once again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeFromMyDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove from My Devices?'),
          content: const Text(
            'This hides the device from your dashboard only. It does not erase WiFi, firmware, timers, schedules, ownership, or the physical switch. You can restore it later from Archived Devices.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      await _deviceService.archiveDeviceForCurrentUser(
        deviceId: widget.deviceId,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        const DeviceSettingsResult(removed: true),
      );
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not remove the device. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          onPressed: _busy ? null : _close,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Device Settings'),
      ),
      body: StreamBuilder<DeviceModel?>(
        stream: _deviceStream,
        builder: (context, deviceSnapshot) {
          final device = deviceSnapshot.data;
          final online = device?.isOnline == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              _DeviceIdentityCard(
                deviceName: _deviceName,
                deviceId: widget.deviceId,
                online: online,
                lastSeen: device?.lastSeenText ?? 'Checking status',
                model: device?.model ?? 'SW1',
              ),
              const SizedBox(height: 22),
              if (device != null)
                _ProductRegistrationCard(device: device),
              const SizedBox(height: 26),
              const _SettingsSectionTitle('Device'),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.edit_rounded,
                    iconColor: AppTheme.primary,
                    title: 'Rename Device',
                    subtitle: 'Change the name shown in your app',
                    onTap: _busy ? null : _renameDevice,
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.wifi_find_rounded,
                    iconColor: Colors.orange,
                    title: 'Change WiFi',
                    subtitle: online
                        ? 'Reset WiFi and open setup mode'
                        : 'Device must be online first',
                    trailing: online
                        ? const Icon(Icons.chevron_right_rounded)
                        : const _OfflinePill(),
                    onTap: _busy ? null : () => _changeWiFi(online: online),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const _SettingsSectionTitle('Account'),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.remove_circle_outline_rounded,
                    iconColor: Colors.red,
                    title: 'Remove from My Devices',
                    subtitle: 'Hide it safely and restore it later',
                    titleColor: Colors.red.shade700,
                    onTap: _busy ? null : _removeFromMyDevices,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SafetyNote(),
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProductRegistrationCard extends StatelessWidget {
  final DeviceModel device;

  const _ProductRegistrationCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final attention = device.registrationNeedsAttention;
    final color = attention ? Colors.orange : Colors.green;
    final icon = attention
        ? Icons.warning_amber_rounded
        : device.isRegistered
        ? Icons.verified_user_rounded
        : Icons.inventory_2_outlined;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.registrationLabel,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.registrationDetail,
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Product ID: ${device.id}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.25,
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

class _RenameDeviceDialog extends StatefulWidget {
  final String initialName;

  const _RenameDeviceDialog({required this.initialName});

  @override
  State<_RenameDeviceDialog> createState() => _RenameDeviceDialogState();
}

class _RenameDeviceDialogState extends State<_RenameDeviceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    Navigator.of(context).pop(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Device'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'e.g. Living Room Switch',
          prefixIcon: Icon(Icons.edit_rounded),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DeviceIdentityCard extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final bool online;
  final String lastSeen;
  final String model;

  const _DeviceIdentityCard({
    required this.deviceName,
    required this.deviceId,
    required this.online,
    required this.lastSeen,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = online ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.memory_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  deviceId,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      height: 9,
                      width: 9,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      online ? 'Online • $lastSeen' : 'Offline • $lastSeen',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      model,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String text;

  const _SettingsSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.darkText,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? AppTheme.darkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? const Icon(Icons.chevron_right_rounded, color: AppTheme.lightText),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 78,
      endIndent: 18,
      color: Colors.black.withValues(alpha: 0.06),
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Offline',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.13)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Change WiFi clears only the saved WiFi credentials. The setup screen now tests new WiFi details before saving them. Your relay, timer and schedule cache remain in the device.',
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

class _ConfirmWifiResetSheet extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ConfirmWifiResetSheet({
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: AppTheme.lightText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Change WiFi connection?',
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The switch will clear its current WiFi, restart, and create EHC_SETUP_A7F92. You will then enter the new WiFi details.',
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.wifi_find_rounded),
                label: const Text('Reset WiFi & Continue'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
