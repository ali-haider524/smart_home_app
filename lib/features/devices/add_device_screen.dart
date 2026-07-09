import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../core/tech_surface.dart';
import '../../services/device_service.dart';
import 'wifi_setup_screen.dart';

/// Step 1 of the device setup flow.
///
/// Claim validation and navigation are intentionally kept on the existing
/// service flow. This screen only simplifies how customers enter those values.
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
      showMessage(context.tr('Please enter Device ID'));
      return;
    }

    if (deviceId.length < 6) {
      showMessage(context.tr('Device ID looks too short'));
      return;
    }

    if (claimCode.isEmpty) {
      showMessage(context.tr('Please enter the claim code printed on the device'));
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
      showMessage(
        context.tr('Could not pair this device. Please check your internet and try again.'),
      );
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
            context.tr(wasRestored ? 'Device restored' : 'Already registered'),
          ),
          content: Text(
            context.languageController.isUrdu
                ? (wasRestored
                    ? '${result.nickname} میری ڈیوائسز میں واپس آ گئی ہے۔ وائی فائی سیٹ اپ کی ضرورت نہیں۔'
                    : '${result.nickname} پہلے ہی آپ کے اکاؤنٹ میں رجسٹرڈ ہے۔ وائی فائی تبدیل کرنے کے لیے Device Settings استعمال کریں۔')
                : (wasRestored
                    ? '${result.nickname} was restored to My Devices. WiFi setup is not needed.'
                    : '${result.nickname} is already registered in your account. Use Device Settings if you want to change WiFi.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Open My Devices')),
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

  void _showLabelHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outline,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('Find your device details'),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.tr('Look for the product label on the switch, its box, or the QR label.'),
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                const _LabelExample(),
                const SizedBox(height: 18),
                const _HelpLine(
                  icon: Icons.tag_rounded,
                  title: 'Device ID',
                  subtitle: 'Usually begins with EHC. Enter it exactly as printed.',
                ),
                const SizedBox(height: 14),
                const _HelpLine(
                  icon: Icons.key_rounded,
                  title: 'Claim code',
                  subtitle: 'A short code that confirms this switch belongs to you.',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(context.tr('Got it')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BackButton(onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          context.tr('Add device'),
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const _StepBadge(current: 1),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TechHeroSurface(
                    padding: const EdgeInsets.all(18),
                    radius: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Pair your switch'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                context.tr('Use the Device ID and Claim Code printed on your product label.'),
                                style: TextStyle(
                                  color: Color(0xFFDCE8FF),
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FlowProgress(current: 1),
                  const SizedBox(height: 20),
                  _PairingFormCard(
                    deviceIdController: deviceIdController,
                    claimCodeController: claimCodeController,
                    deviceNameController: deviceNameController,
                    onHelp: _showLabelHelp,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: isPairing ? null : claimAndContinue,
                      icon: isPairing
                          ? const SizedBox(
                              height: 19,
                              width: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.link_rounded),
                      label: Text(
                        isPairing ? context.tr('Checking device…') : context.tr('Continue to Wi-Fi'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  const _PairingSecurityNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowProgress extends StatelessWidget {
  final int current;

  const _FlowProgress({required this.current});

  @override
  Widget build(BuildContext context) {
    final labels = [context.tr('Pair'), context.tr('Wi-Fi'), context.tr('Ready')];

    return Row(
      children: List.generate(labels.length, (index) {
        final step = index + 1;
        final active = step <= current;

        return Expanded(
          child: Row(
            children: [
              Container(
                height: 28,
                width: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primaryDark : AppTheme.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$step',
                  style: TextStyle(
                    color: active ? Colors.white : AppTheme.lightText,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: active ? AppTheme.darkText : AppTheme.lightText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (index != labels.length - 1)
                Container(
                  width: 16,
                  height: 1,
                  color: AppTheme.outline,
                ),
              if (index != labels.length - 1) const SizedBox(width: 7),
            ],
          ),
        );
      }),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final int current;

  const _StepBadge({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        context.languageController.isUrdu ? 'مرحلہ $current از 3' : 'Step $current of 3',
        style: const TextStyle(
          color: AppTheme.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PairingFormCard extends StatelessWidget {
  final TextEditingController deviceIdController;
  final TextEditingController claimCodeController;
  final TextEditingController deviceNameController;
  final VoidCallback onHelp;

  const _PairingFormCard({
    required this.deviceIdController,
    required this.claimCodeController,
    required this.deviceNameController,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Product label details'),
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('Use the information printed on your switch.'),
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onHelp,
                child: Text(context.tr('Where is it?')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: deviceIdController,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: context.tr('Device ID'),
              hintText: context.tr('Example: EHC001A7F92'),
              prefixIcon: const Icon(Icons.tag_rounded),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: claimCodeController,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: context.tr('Claim code'),
              hintText: context.tr('Example: 8K29P4'),
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: deviceNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.tr('Device name (optional)'),
              hintText: context.tr('Example: Bedroom light'),
              prefixIcon: const Icon(Icons.edit_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingSecurityNote extends StatelessWidget {
  const _PairingSecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, color: AppTheme.lightText, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr('The claim code verifies ownership. Your home Wi-Fi password is requested in the next step only.'),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabelExample extends StatelessWidget {
  const _LabelExample();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'EASY HOME CONTROL',
            style: TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 12),
          _LabelValue(label: 'DEVICE ID', value: 'EHC001A7F92'),
          SizedBox(height: 9),
          _LabelValue(label: 'CLAIM CODE', value: '8K29P4'),
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 94,
          child: Text(
            context.tr(label),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _HelpLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HelpLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryDark, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(title),
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr(subtitle),
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
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          width: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.darkText,
            size: 21,
          ),
        ),
      ),
    );
  }
}
