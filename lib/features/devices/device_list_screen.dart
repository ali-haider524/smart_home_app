import 'package:flutter/material.dart';
import 'add_device_screen.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Devices')),
      floatingActionButton: FloatingActionButton(
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
          padding: const EdgeInsets.all(16),
          children: const [
            DeviceCard(name: 'Bedroom Fan', status: 'Online', isOn: true),
            SizedBox(height: 12),
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
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.power_settings_new,
          color: isOn ? Colors.green : Colors.grey,
        ),
        title: Text(name),
        subtitle: Text(status),
        trailing: Switch(value: isOn, onChanged: (_) {}),
      ),
    );
  }
}