import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_theme.dart';

class WifiSetupScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const WifiSetupScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final wifiNameController = TextEditingController();
  final wifiPasswordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    wifiNameController.dispose();
    wifiPasswordController.dispose();
    super.dispose();
  }

  Future<void> sendWifiDetails() async {
    final ssid = wifiNameController.text.trim();
    final password = wifiPasswordController.text.trim();

    if (ssid.isEmpty || password.isEmpty) {
      showMessage('Please enter WiFi name and password');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http
          .post(
        Uri.parse('http://192.168.4.1/save'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ssid': ssid,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        showMessage('WiFi saved. Device is restarting...');
      } else {
        showMessage('Device error: ${response.body}');
      }
    } catch (e) {
      showMessage(
        'Failed to connect to device. Make sure your phone is connected to EHC_SETUP_A7F92 hotspot.',
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
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
                    'WiFi Setup',
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
                'Connect your device',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkText,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'First connect your phone to EHC_SETUP_A7F92 hotspot. Then enter your home WiFi details below.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.lightText,
                ),
              ),

              const SizedBox(height: 24),

              _DeviceInfoCard(
                deviceId: widget.deviceId,
                deviceName: widget.deviceName,
              ),

              const SizedBox(height: 22),

              _SoftCard(
                child: Column(
                  children: [
                    TextField(
                      controller: wifiNameController,
                      decoration: const InputDecoration(
                        hintText: 'WiFi Name / SSID',
                        prefixIcon: Icon(Icons.wifi_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: wifiPasswordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        hintText: 'WiFi Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => hidePassword = !hidePassword);
                          },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
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
                  onPressed: isLoading ? null : sendWifiDetails,
                  icon: isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    isLoading ? 'Sending...' : 'Send WiFi Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Security note: WiFi password is sent only to the ESP device during setup. It is not stored in Firebase.',
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

class _DeviceInfoCard extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const _DeviceInfoCard({
    required this.deviceId,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1E40AF),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  deviceId,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 0.5,
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

class _SoftCard extends StatelessWidget {
  final Widget child;

  const _SoftCard({required this.child});

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
      child: child,
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