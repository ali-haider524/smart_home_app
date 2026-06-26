import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'add_device_screen.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Devices')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            DeviceCard(name: 'Bedroom Fan', status: 'Online', isOn: true),
            SizedBox(height: 16),
            DeviceCard(name: 'Kitchen Light', status: 'Offline', isOn: false),
          ],
        ),
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final String name;
  final String status;
  final bool isOn;

  const DeviceCard({
    super.key,
    required this.name,
    required this.status,
    required this.isOn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
            isOn ? AppTheme.primary.withOpacity(0.12) : Colors.grey.shade200,
            child: Icon(
              Icons.power_settings_new,
              color: isOn ? AppTheme.primary : Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    color: isOn ? Colors.green : AppTheme.lightText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOn,
            activeColor: AppTheme.primary,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}