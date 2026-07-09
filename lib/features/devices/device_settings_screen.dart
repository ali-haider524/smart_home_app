import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_language.dart';
import '../../core/app_theme.dart';
import '../../core/tech_surface.dart';
import '../../models/device_access.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';
import 'device_access_screen.dart';
import 'energy_estimate_settings_screen.dart';
import 'wifi_setup_screen.dart';

/// Returned to DeviceControlScreen after settings changes.
class DeviceSettingsResult {
  final String? nickname;
  final bool removed;
  final bool openWiFiSetup;

  /// True only for an already registered device. DeviceControlScreen then
  /// opens the local Wi-Fi screen in recovery mode without repeating pairing.
  final bool openWiFiRecovery;

  const DeviceSettingsResult({
    this.nickname,
    this.removed = false,
    this.openWiFiSetup = false,
    this.openWiFiRecovery = false,
  });
}

/// Safe per-device settings.
///
/// It deliberately does not write to command/state/timer/schedule paths.
/// Wi-Fi setup uses a separate maintenance/openWifiSetup contract. It opens
/// the local setup hotspot without clearing the previous credentials first.
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
  late final Stream<DeviceAccessInfo> _accessStream;
  bool _busy = false;

  // This is kept separate from the short rename/archive operations so Wi-Fi
  // setup always gives immediate, central feedback instead of a hidden loader
  // at the bottom of the settings page.
  bool _openingWiFiSetup = false;
  String _wifiSetupProgress = '';

  @override
  void initState() {
    super.initState();
    _deviceName = widget.initialDeviceName.trim().isEmpty
        ? 'Smart Switch'
        : widget.initialDeviceName.trim();
    _deviceStream = _deviceService.listenDevice(widget.deviceId);
    _accessStream = _deviceService.listenCurrentUserDeviceAccess(widget.deviceId);
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
      _showMessage(context.tr('Device renamed'));
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(context.tr('Could not rename the device. Please try again.'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openEnergyEstimateSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EnergyEstimateSettingsScreen(
          deviceId: widget.deviceId,
          deviceName: _deviceName,
        ),
      ),
    );
  }

  Future<void> _openManageAccess() async {
    final ownershipTransferred = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceAccessScreen(
          deviceId: widget.deviceId,
          deviceName: _deviceName,
        ),
      ),
    );

    // After a completed transfer this account is deliberately removed from the
    // device. Closing the settings/control route prevents stale screen data.
    if (ownershipTransferred == true && mounted) {
      Navigator.pop(context, const DeviceSettingsResult(removed: true));
    }
  }

  Future<void> _changeWiFi({required bool online}) async {
    // When the switch is offline, Firebase cannot reach it. Guide the owner
    // directly to local recovery instead of showing a blocked setting.
    if (!online) {
      await _openOfflineWiFiRecovery();
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ConfirmWifiRecoverySheet(
          hotspotName: WifiSetupScreen.hotspotNameForDevice(widget.deviceId),
          onCancel: () => Navigator.pop(sheetContext, false),
          onConfirm: () => Navigator.pop(sheetContext, true),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _openingWiFiSetup = true;
      _wifiSetupProgress = context.tr('Contacting your switch…');
    });
    var openingWiFiSetup = false;

    try {
      // Firmware opens AP+STA recovery mode and acknowledges it without
      // clearing EEPROM credentials. New details replace the old values only
      // after the ESP joins the new network successfully.
      final requestId = await _deviceService.requestWiFiSetupMode(
        deviceId: widget.deviceId,
      );

      if (!mounted) return;
      setState(() {
        _wifiSetupProgress = context.tr('Waiting for the switch to open Wi-Fi setup…');
      });

      final acknowledged = await _deviceService.waitForWiFiSetupModeAcknowledgement(
        deviceId: widget.deviceId,
        requestId: requestId,
      );

      if (!mounted) return;

      if (!acknowledged) {
        await _showWiFiSetupTimeoutDialog();
        return;
      }

      // Return the hand-off result to DeviceControlScreen. It owns the next
      // navigation step, avoiding route replacement while this page's stream
      // widgets are being disposed.
      openingWiFiSetup = true;
      setState(() {
        _busy = false;
        _openingWiFiSetup = false;
        _wifiSetupProgress = '';
      });
      if (!mounted) return;

      Navigator.pop(
        context,
        DeviceSettingsResult(
          nickname: _deviceName,
          openWiFiSetup: true,
          openWiFiRecovery: true,
        ),
      );
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
        context.tr('Could not open Wi-Fi setup. Check the device connection and try again.'),
      );
    } finally {
      if (mounted && !openingWiFiSetup) {
        setState(() {
          _busy = false;
          _openingWiFiSetup = false;
          _wifiSetupProgress = '';
        });
      }
    }
  }

  Future<void> _openOfflineWiFiRecovery() async {
    final startRecovery = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _OfflineWifiRecoverySheet(
          hotspotName: WifiSetupScreen.hotspotNameForDevice(widget.deviceId),
          onCancel: () => Navigator.pop(sheetContext, false),
          onContinue: () => Navigator.pop(sheetContext, true),
        );
      },
    );

    if (startRecovery != true || !mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WifiSetupScreen(
          deviceId: widget.deviceId,
          deviceName: _deviceName,
          recoveryMode: true,
        ),
      ),
    );
  }

  Future<void> _showWiFiSetupTimeoutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('Switch did not confirm yet')),
          content: Text(
            context.tr(
              'The safe Wi-Fi setup request was sent, but the app did not receive an acknowledgement. Keep the switch powered. If it is offline, use Reconnect Wi-Fi and open the local hotspot instead.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('OK')),
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
          title: Text(context.tr('Remove from My Devices?')),
          content: Text(
            context.tr(
              'This hides the device from your dashboard only. It does not erase WiFi, firmware, timers, schedules, ownership, or the physical switch. You can restore it later from Archived Devices.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Remove')),
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
      _showMessage(context.tr('Could not remove the device. Please try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_openingWiFiSetup,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            onPressed: _busy ? null : _close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(context.tr('Device settings')),
        ),
        body: StreamBuilder<DeviceAccessInfo>(
          stream: _accessStream,
          initialData: DeviceAccessInfo.empty(widget.deviceId),
          builder: (context, accessSnapshot) {
            final access =
                accessSnapshot.data ?? DeviceAccessInfo.empty(widget.deviceId);
            final isOwner = access.isOwner;

            return StreamBuilder<DeviceModel?>(
              stream: _deviceStream,
              builder: (context, deviceSnapshot) {
                final device = deviceSnapshot.data;
                final online = device?.isOnline == true;

                return Stack(
                  children: [
                    ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
                      children: [
                        _DeviceIdentityCard(
                          deviceName: _deviceName,
                          deviceId: widget.deviceId,
                          online: online,
                          lastSeen: device?.lastSeenText ?? context.tr('Checking status'),
                          model: device?.model ?? 'SW1',
                        ),
                        if (device?.registrationNeedsAttention == true) ...[
                          const SizedBox(height: 12),
                          _ProductRegistrationCard(device: device!),
                        ],
                        const SizedBox(height: 22),
                        const _SettingsSectionTitle('Controls'),
                        const SizedBox(height: 10),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.edit_rounded,
                              iconColor: AppTheme.primary,
                              title: 'Rename device',
                              subtitle: 'Change the name shown in your app',
                              onTap: _busy ? null : _renameDevice,
                            ),
                            const _SettingsDivider(),
                            _SettingsTile(
                              icon: Icons.energy_savings_leaf_outlined,
                              iconColor: AppTheme.success,
                              title: 'Estimated energy',
                              subtitle: 'Appliance watts and optional electricity price',
                              onTap: _busy ? null : _openEnergyEstimateSettings,
                            ),
                            if (isOwner) ...[
                              const _SettingsDivider(),
                              _SettingsTile(
                                icon: Icons.groups_rounded,
                                iconColor: AppTheme.primaryDark,
                                title: 'Manage access',
                                subtitle: 'Share this device or transfer ownership',
                                onTap: _busy ? null : _openManageAccess,
                              ),
                              const _SettingsDivider(),
                              _SettingsTile(
                                icon: online
                                    ? Icons.wifi_find_rounded
                                    : Icons.wifi_tethering_rounded,
                                iconColor: Colors.orange,
                                title: 'Wi-Fi & recovery',
                                subtitle: online
                                    ? 'Change home Wi-Fi or open the setup hotspot. Use the password on the device label or box.'
                                    : 'Reconnect after a router or Wi-Fi password change. Keep the device label or box nearby.',
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.lightText,
                                ),
                                onTap:
                                _busy ? null : () => _changeWiFi(online: online),
                              ),
                            ],
                          ],
                        ),
                        if (!isOwner) ...[
                          const SizedBox(height: 13),
                          const _SharedMemberSettingsNote(),
                        ],
                        const SizedBox(height: 22),
                        const _SettingsSectionTitle('Device information'),
                        const SizedBox(height: 10),
                        if (device != null)
                          _DeviceInformationCard(device: device)
                        else
                          _DeviceInformationPlaceholder(deviceId: widget.deviceId),
                        const SizedBox(height: 22),
                        const _SettingsSectionTitle('Device management'),
                        const SizedBox(height: 10),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.inventory_2_outlined,
                              iconColor: Colors.red,
                              title: 'Archive device',
                              subtitle: 'Hide it from Home and restore it later',
                              titleColor: Colors.red.shade700,
                              onTap: _busy ? null : _removeFromMyDevices,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _SafetyNote(),
                      ],
                    ),
                    if (_openingWiFiSetup)
                      _WiFiSetupOpeningOverlay(
                        hotspotName: WifiSetupScreen.hotspotNameForDevice(
                          widget.deviceId,
                        ),
                        progress: _wifiSetupProgress,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WiFiSetupOpeningOverlay extends StatelessWidget {
  final String hotspotName;
  final String progress;

  const _WiFiSetupOpeningOverlay({
    required this.hotspotName,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.26),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.11),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_find_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    context.tr('Opening Wi-Fi setup'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress.isEmpty
                        ? context.tr('Please wait while your switch prepares setup.')
                        : progress,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.lightText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '${context.tr('Next, connect your phone to')} $hotspotName. ${context.tr('Do not press Change Wi-Fi again.')}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
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

class _SharedMemberSettingsNote extends StatelessWidget {
  const _SharedMemberSettingsNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.groups_outlined, color: AppTheme.primaryDark),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('You have shared access. You can control power, timers, and your own energy estimate. The owner manages Wi-Fi, schedules, and access.'),
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
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
                  context.tr(device.registrationLabel),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(device.registrationDetail),
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.tr('Product ID')}: ${device.id}',
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
      title: Text(context.tr('Rename Device')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: context.tr('e.g. Living Room Switch'),
          prefixIcon: const Icon(Icons.edit_rounded),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.tr('Save')),
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
    final statusColor = online ? const Color(0xFF74F1B2) : const Color(0xFFFFD47C);
    final statusText = online
        ? '${context.tr('Online')} · $lastSeen'
        : '${context.tr('Offline')} · $lastSeen';

    return TechHeroSurface(
      padding: const EdgeInsets.all(17),
      radius: 24,
      colors: online
          ? const [AppTheme.primaryDark, AppTheme.primary, AppTheme.electric]
          : const [Color(0xFF334968), Color(0xFF526D92), Color(0xFF7196C6)],
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.17)),
            ),
            child: const Icon(
              Icons.power_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$model · $deviceId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 7,
                        width: 7,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _DeviceInformationCard extends StatelessWidget {
  final DeviceModel device;

  const _DeviceInformationCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _settingsCardDecoration(),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Colors.blueGrey,
                size: 21,
              ),
            ),
            title: Text(
              context.tr('Device details'),
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              '${device.model} · ${device.firmwareVersion}',
              style: TextStyle(color: AppTheme.lightText, fontSize: 12),
            ),
            children: [
              _InfoLine(label: 'Device ID', value: device.id),
              _InfoLine(label: 'Model', value: device.model),
              _InfoLine(label: 'Firmware', value: device.firmwareVersion),
              _InfoLine(
                label: 'Channels',
                value: device.channelCount == 1
                    ? '${device.channelCount} ${context.tr('channel')}'
                    : '${device.channelCount} ${context.tr('channels')}',
              ),
              _InfoLine(label: 'Product status', value: context.tr(device.registrationLabel)),
              _InfoLine(label: 'Last seen', value: device.lastSeenText),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceInformationPlaceholder extends StatelessWidget {
  final String deviceId;

  const _DeviceInformationPlaceholder({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _settingsCardDecoration(),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.lightText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${context.tr('Device information will appear when')} $deviceId ${context.tr('is available.')}',
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              context.tr(label),
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
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
      context.tr(text),
      style: TextStyle(
        color: AppTheme.darkText,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

BoxDecoration _settingsCardDecoration() {
  return BoxDecoration(
    color: AppTheme.card,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppTheme.outline),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
    ],
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _settingsCardDecoration(),
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
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(title),
                      style: TextStyle(
                        color: titleColor ?? AppTheme.darkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr(subtitle),
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? Icon(Icons.chevron_right_rounded, color: AppTheme.lightText),
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
      child: Text(
        context.tr('Offline'),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('Wi-Fi setup only updates the switch network. Your controls, timers, schedules, and access stay unchanged.'),
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

class _OfflineWifiRecoverySheet extends StatelessWidget {
  final String hotspotName;
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  const _OfflineWifiRecoverySheet({
    required this.hotspotName,
    required this.onCancel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
            Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.wifi_tethering_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('Reconnect an offline switch'),
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('The app cannot change Wi-Fi through Firebase while the switch is offline. Use the switch recovery hotspot instead. This does not pair the device again or change ownership.'),
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            _RecoveryInstructionRow(
              number: '1',
              text: 'Keep the switch powered. Hold the Wi-Fi button for 3 seconds, release it, then wait 10 seconds. If the button is not available, keep the switch powered and wait about 1 minute for automatic recovery.',
            ),
            const SizedBox(height: 10),
            _RecoveryInstructionRow(
              number: '2',
              text: '${context.tr('Open phone Wi-Fi settings and connect to')} $hotspotName. ${context.tr('Choose “Stay connected” if your phone says the hotspot has no internet.')}',
            ),
            const SizedBox(height: 10),
            _RecoveryInstructionRow(
              number: '3',
              text: context.tr('Return here, continue, and test the hotspot before entering the new home Wi-Fi details.'),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(context.tr('I am connected to the hotspot')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onCancel,
                child: Text(context.tr('Cancel')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryInstructionRow extends StatelessWidget {
  final String number;
  final String text;

  const _RecoveryInstructionRow({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 23,
          width: 23,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.tr(text),
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 13,
              height: 1.36,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmWifiRecoverySheet extends StatelessWidget {
  final String hotspotName;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ConfirmWifiRecoverySheet({
    required this.hotspotName,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        decoration: BoxDecoration(
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
            Text(
              context.tr('Open Wi-Fi setup?'),
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${context.tr('The switch will create')} $hotspotName. ${context.tr('Your current Wi-Fi stays saved until the new network works.')}',
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
                label: Text(context.tr('Open Wi-Fi setup')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onCancel,
                child: Text(context.tr('Cancel')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
