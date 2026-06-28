import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/device_service.dart';
import 'wifi_setup_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _deviceService = DeviceService();

  final deviceIdController = TextEditingController();
  final claimCodeController = TextEditingController();
  final deviceNameController = TextEditingController();

  bool isPairing = false;

  @override
  void dispose() {
    deviceIdController.dispose();
    claimCodeController.dispose();
    deviceNameController.dispose();
    super.dispose();
  }

  Future<void> claimAndContinue() async {
    final deviceId = deviceIdController.text.trim().toUpperCase();
    final claimCode = claimCodeController.text.trim().toUpperCase();
    final deviceName = deviceNameController.text.trim().isEmpty
        ? 'Smart Switch'
        : deviceNameController.text.trim();

    if (deviceId.isEmpty) {
      showMessage('Please enter Device ID');
      return;
    }

    if (deviceId.length < 6) {
      showMessage('Device ID looks too short');
      return;
    }

    if (claimCode.isEmpty) {
      showMessage('Please enter the claim code printed on the device');
      return;
    }

    setState(() => isPairing = true);

    try {
      final result = await _deviceService.claimDeviceForCurrentUser(
        deviceId: deviceId,
        claimCode: claimCode,
        nickname: deviceName,
      );

      if (!mounted) return;

      if (result.needsWiFiSetup) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WifiSetupScreen(
              deviceId: result.deviceId,
              deviceName: result.nickname,
            ),
          ),
        );
        return;
      }

      await _showExistingRegistrationDialog(result);
    } on DeviceClaimException catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage('Could not pair this device. Please check your internet and try again.');
    } finally {
      if (mounted) {
        setState(() => isPairing = false);
      }
    }
  }

  Future<void> _showExistingRegistrationDialog(
      DeviceClaimResult result,
      ) async {
    final wasRestored = result.outcome == DeviceClaimOutcome.restoredFromArchive;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            wasRestored ? Icons.unarchive_rounded : Icons.verified_rounded,
            color: Colors.green,
            size: 34,
          ),
          title: Text(
            wasRestored ? 'Device restored' : 'Already registered',
          ),
          content: Text(
            wasRestored
                ? '${result.nickname} was restored to My Devices. WiFi setup is not needed.'
                : '${result.nickname} is already registered in your account. Use Device Settings if you want to change WiFi.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Open My Devices'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SoftBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 14),
                  const Text(
                    'Add Device',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Pair your smart switch',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkText,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter the Device ID and claim code printed on the product label. The claim code keeps another account from adding your switch.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.lightText,
                ),
              ),
              const SizedBox(height: 28),
              const _PairingStepCard(
                step: '01',
                title: 'Find the product label',
                subtitle: 'You will find Device ID and Claim Code on the switch, box, or QR label.',
                icon: Icons.qr_code_2_rounded,
                child: _HintChipRow(),
              ),
              const SizedBox(height: 20),
              _PairingStepCard(
                step: '02',
                title: 'Enter device details',
                subtitle: 'Pair the device first. WiFi setup comes after successful pairing.',
                icon: Icons.memory_rounded,
                child: Column(
                  children: [
                    TextField(
                      controller: deviceIdController,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'Device ID e.g. EHC001A7F92',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: claimCodeController,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'Claim code e.g. 8K29P4',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: deviceNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Device name e.g. Bedroom Light',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: isPairing ? null : claimAndContinue,
                  icon: isPairing
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.link_rounded),
                  label: Text(
                    isPairing ? 'Pairing device...' : 'Pair & Continue to WiFi',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Your WiFi password is never saved in Firebase. It is sent directly to the ESP only while your phone is connected to the EHC setup hotspot.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.lightText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintChipRow extends StatelessWidget {
  const _HintChipRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: const [
        _HintChip(icon: Icons.tag_rounded, text: 'Device ID'),
        _HintChip(icon: Icons.key_rounded, text: 'Claim Code'),
        _HintChip(icon: Icons.wifi_rounded, text: 'WiFi Setup Next'),
      ],
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingStepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _PairingStepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(10, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.95),
            blurRadius: 18,
            offset: const Offset(-8, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.lightText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SoftBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SoftBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(6, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                blurRadius: 14,
                offset: const Offset(-6, -6),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.darkText,
          ),
        ),
      ),
    );
  }
}
