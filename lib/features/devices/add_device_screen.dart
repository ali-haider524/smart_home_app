import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'wifi_setup_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final deviceIdController = TextEditingController();
  final deviceNameController = TextEditingController();

  @override
  void dispose() {
    deviceIdController.dispose();
    deviceNameController.dispose();
    super.dispose();
  }

  void continueToWifiSetup() {
    final deviceId = deviceIdController.text.trim();
    final deviceName = deviceNameController.text.trim();

    if (deviceId.isEmpty) {
      showMessage('Please enter Device ID');
      return;
    }

    if (deviceId.length < 6) {
      showMessage('Device ID looks too short');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WifiSetupScreen(
          deviceId: deviceId,
          deviceName: deviceName.isEmpty ? 'Smart Switch' : deviceName,
        ),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
                'Scan the QR code on your device box or enter the Device ID manually.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.lightText,
                ),
              ),

              const SizedBox(height: 28),

              _PairingStepCard(
                step: '01',
                title: 'Scan QR Code',
                subtitle: 'Fastest and safest way to pair your device.',
                icon: Icons.qr_code_scanner_rounded,
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      showMessage('QR scanner will be added in next step');
                    },
                    icon: const Icon(Icons.qr_code_rounded),
                    label: const Text(
                      'Scan QR Code',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _PairingStepCard(
                step: '02',
                title: 'Device Details',
                subtitle: 'Use the Device ID printed on your smart switch.',
                icon: Icons.memory_rounded,
                child: Column(
                  children: [
                    TextField(
                      controller: deviceIdController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Device ID e.g. EHC001A7F92',
                        prefixIcon: Icon(Icons.tag_rounded),
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
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: continueToWifiSetup,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Continue to WiFi Setup',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'WiFi password is sent only to the device during setup. It is never stored in Firebase.',
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
            color: Colors.black.withOpacity(0.06),
            blurRadius: 28,
            offset: const Offset(10, 14),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.95),
            blurRadius: 18,
            offset: const Offset(-8, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(7, 7),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.95),
                      blurRadius: 14,
                      offset: const Offset(-7, -7),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STEP $step',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.lightText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(6, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
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