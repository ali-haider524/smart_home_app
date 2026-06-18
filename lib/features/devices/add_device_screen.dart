import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'wifi_setup_screen.dart';

class AddDeviceScreen extends StatelessWidget {
  const AddDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceIdController = TextEditingController();
    final deviceNameController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pair your smart switch',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Scan QR code or enter Device ID manually.'),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 64),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Scan QR Code'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              TextField(
                controller: deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Device ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'Bedroom Fan',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WifiSetupScreen(),
                      ),
                    );
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}