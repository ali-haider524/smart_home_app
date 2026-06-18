import 'package:flutter/material.dart';

class WifiSetupScreen extends StatelessWidget {
  const WifiSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wifiNameController = TextEditingController();
    final wifiPasswordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('WiFi Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Connect device to WiFi',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your home WiFi details. These details will be sent to the ESP device, not stored in Firebase.',
              ),
              const SizedBox(height: 32),

              TextField(
                controller: wifiNameController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Name / SSID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: wifiPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'WiFi Password',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Send WiFi Details to Device'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}