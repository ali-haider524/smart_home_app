import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_access.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';
import 'wifi_setup_screen.dart';

/// One clear entry point for owner-managed device Wi-Fi.
///
/// Online switches can open their setup hotspot remotely. Offline switches use
/// the local recovery hotspot. Neither path changes pairing or ownership.
class ReconnectDeviceScreen extends StatefulWidget {
  const ReconnectDeviceScreen({super.key});

  @override
  State<ReconnectDeviceScreen> createState() => _ReconnectDeviceScreenState();
}

class _ReconnectDeviceScreenState extends State<ReconnectDeviceScreen> {
  final DeviceService _deviceService = DeviceService();
  late final Stream<List<DeviceModel>> _devicesStream;

  String? _openingDeviceId;
  String _openingMessage = '';

  @override
  void initState() {
    super.initState();
    _devicesStream = _deviceService.listenAllDevices();
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  Future<void> _openDeviceWifi(DeviceModel device) async {
    if (_openingDeviceId != null) return;

    setState(() {
      _openingDeviceId = device.id;
      _openingMessage = '';
    });

    try {
      final access = await _deviceService.getCurrentUserDeviceAccess(device.id);
      if (!access.isOwner) {
        _showMessage(
          context.tr('Only the device owner can change its Wi-Fi connection.'),
          type: AppNoticeType.error,
        );
        return;
      }

      if (device.isOnline) {
        final confirmed = await _confirmOpenOnlineSetup(device);
        if (confirmed != true || !mounted) return;

        setState(() {
          _openingMessage = context.tr('Asking the switch to open its secure setup Wi-Fi…');
        });

        final requestId = await _deviceService.requestWiFiSetupMode(
          deviceId: device.id,
        );

        if (!mounted) return;
        setState(() {
          _openingMessage = context.tr('Waiting for the switch to confirm…');
        });

        final acknowledged =
            await _deviceService.waitForWiFiSetupModeAcknowledgement(
          deviceId: device.id,
          requestId: requestId,
        );

        if (!mounted) return;

        if (!acknowledged) {
          _showMessage(
            context.tr('The switch did not confirm setup mode. Check that it is online, then try again.'),
            type: AppNoticeType.error,
          );
          return;
        }
      }

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => WifiSetupScreen(
            deviceId: device.id,
            deviceName: device.nickname,
            recoveryMode: true,
          ),
        ),
      );
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
    } catch (_) {
      _showMessage(
        context.tr('Could not open device Wi-Fi. Check your connection and try again.'),
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingDeviceId = null;
          _openingMessage = '';
        });
      }
    }
  }

  Future<bool?> _confirmOpenOnlineSetup(DeviceModel device) {
    final hotspotName = WifiSetupScreen.hotspotNameForDevice(device.id);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.wifi_tethering_rounded, color: AppTheme.primary),
          title: Text(context.tr('Open switch setup Wi-Fi?')),
          content: Text(
            context.languageController.isUrdu
                ? '${device.nickname} $hotspotName کھولے گا۔ نیا نیٹ ورک قبول ہونے تک موجودہ ہوم وائی فائی محفوظ رہے گا۔ آپ کو ڈیوائس لیبل یا باکس پر پرنٹ سیٹ اپ پاس ورڈ چاہیے ہوگا۔'
                : '${device.nickname} will open $hotspotName. Its current home Wi-Fi stays saved until the new network is accepted. You will need the setup password printed on the device label or box.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Open setup Wi-Fi')),
            ),
          ],
        );
      },
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
        title: Text(context.tr('Device Wi-Fi')),
      ),
      body: StreamBuilder<List<DeviceModel>>(
        stream: _devicesStream,
        builder: (context, snapshot) {
          final devices = snapshot.data ?? const <DeviceModel>[];

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
            children: [
              Text(
                context.tr('Wi-Fi & recovery'),
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                context.tr('Change a switch to a new home Wi-Fi, or reconnect it after a router or password change.'),
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              const _BeforeYouStartCard(),
              const SizedBox(height: 22),
              Text(
                context.tr('Choose a switch'),
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (snapshot.hasError)
                const _InfoCard(
                  icon: Icons.error_outline_rounded,
                  color: Colors.red,
                  title: 'Could not load devices',
                  message: 'Check your internet connection and try again.',
                )
              else if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 34),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (devices.isEmpty)
                const _InfoCard(
                  icon: Icons.devices_other_outlined,
                  color: AppTheme.primary,
                  title: 'No registered switch found',
                  message: 'Add your first Easy Home Control switch before managing device Wi-Fi.',
                )
              else
                ...devices.map(_buildDeviceCard),
              const SizedBox(height: 18),
              const _InfoCard(
                icon: Icons.info_outline_rounded,
                color: AppTheme.warning,
                title: 'Offline switch?',
                message: 'Keep it powered. The next screen will show the shortest way to open its setup hotspot and reconnect it.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    final opening = _openingDeviceId == device.id;
    final online = device.isOnline;
    final accent = online ? AppTheme.success : AppTheme.warning;
    final actionLabel = online ? context.tr('Change Wi-Fi') : context.tr('Reconnect');
    final subtitle = online
        ? context.tr('Online · Open setup Wi-Fi remotely')
        : context.tr('Offline · Use the local recovery hotspot');

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: opening ? null : () => _openDeviceWifi(device),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.outline),
            ),
            child: Row(
              children: [
                Container(
                  height: 45,
                  width: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: accent,
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
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.lightText,
                          fontSize: 12,
                        ),
                      ),
                      if (opening && _openingMessage.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          _openingMessage,
                          style: TextStyle(
                            color: AppTheme.primaryDark,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (opening)
                  SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2.2,
                    ),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.primaryDark,
                        size: 22,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BeforeYouStartCard extends StatelessWidget {
  const _BeforeYouStartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryDark),
              const SizedBox(width: 9),
              Text(
                context.tr('Before you start'),
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            context.tr('Keep the device label or product box nearby. You need the setup hotspot password printed there. The Device ID identifies the switch; the Claim Code is only needed when adding a new switch to an account.'),
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.17)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(title),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(message),
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                    height: 1.35,
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
