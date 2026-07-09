import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/energy_estimate.dart';
import '../../services/device_service.dart';

/// Lets a customer configure an optional, transparent energy estimate.
///
/// The switch does not receive these values and no device command/state path is
/// touched. This screen stores personal display preferences only under the
/// signed-in user's own device mapping.
class EnergyEstimateSettingsScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const EnergyEstimateSettingsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<EnergyEstimateSettingsScreen> createState() =>
      _EnergyEstimateSettingsScreenState();
}

class _EnergyEstimateSettingsScreenState
    extends State<EnergyEstimateSettingsScreen> {
  final DeviceService _deviceService = DeviceService();
  final TextEditingController _wattsController = TextEditingController();
  final TextEditingController _unitRateController = TextEditingController();

  StreamSubscription<EnergyEstimateSettings>? _settingsSubscription;
  EnergyEstimateSettings _settings = EnergyEstimateSettings.empty;
  bool _initialValuesApplied = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _settingsSubscription =
        _deviceService.listenEnergyEstimateSettings(widget.deviceId).listen(
              (settings) {
            if (!mounted) return;

            if (!_initialValuesApplied) {
              _wattsController.text =
              settings.isConfigured ? settings.ratedWatts.toString() : '';
              _unitRateController.text = settings.hasUnitRate
                  ? _formatEditableNumber(settings.unitRate)
                  : '';
              _initialValuesApplied = true;
            }

            setState(() {
              _settings = settings;
              _loading = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
        );
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _wattsController.dispose();
    _unitRateController.dispose();
    super.dispose();
  }

  String _formatEditableNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toString();
  }

  void _setWatts(int watts) {
    setState(() => _wattsController.text = watts.toString());
  }

  Future<void> _save() async {
    final watts = int.tryParse(_wattsController.text.trim());
    final rawRate = _unitRateController.text.trim();
    final double? unitRate =
    rawRate.isEmpty ? 0.0 : double.tryParse(rawRate);

    if (watts == null || watts < 1 || watts > 20000) {
      _showMessage('Enter appliance power between 1 and 20,000 watts.');
      return;
    }

    if (unitRate == null || unitRate < 0 || unitRate > 10000) {
      _showMessage('Enter a valid electricity price, or leave it empty.');
      return;
    }

    setState(() => _saving = true);

    try {
      await _deviceService.saveEnergyEstimateSettings(
        deviceId: widget.deviceId,
        ratedWatts: watts,
        unitRate: unitRate,
      );

      if (!mounted) return;
      _showMessage('Energy estimate settings saved.', type: AppNoticeType.success);
      Navigator.pop(context);
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
    } catch (_) {
      _showMessage(
        'Could not save energy settings. Check your internet connection and try again.',
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.deviceName.trim().isEmpty
        ? 'Smart Switch'
        : widget.deviceName.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('Energy estimate'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
        children: [
          _EstimateHero(deviceName: name, settings: _settings),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'Appliance details',
            subtitle: 'Use the power rating printed on your appliance label.',
          ),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _wattsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Appliance power',
                    hintText: 'Example: 60',
                    suffixText: 'W',
                    prefixIcon: Icon(Icons.bolt_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Common examples',
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PowerPreset(label: 'Light 60W', watts: 60, onTap: _setWatts),
                    _PowerPreset(label: 'Fan 100W', watts: 100, onTap: _setWatts),
                    _PowerPreset(label: 'TV 150W', watts: 150, onTap: _setWatts),
                    _PowerPreset(label: 'Iron 1000W', watts: 1000, onTap: _setWatts),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle(
            title: 'Electricity price',
            subtitle: 'Optional. Add your own rate to see an approximate cost.',
          ),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _unitRateController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price per unit',
                    hintText: 'Leave empty to show kWh only',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                    suffixText: 'Rs / kWh',
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  'One electricity unit equals 1 kWh. Your bill rate may vary by tariff, taxes, and slab.',
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _EstimateNotice(),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                height: 19,
                width: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save energy settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimateHero extends StatelessWidget {
  final String deviceName;
  final EnergyEstimateSettings settings;

  const _EstimateHero({
    required this.deviceName,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final configured = settings.isConfigured;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 27,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  configured
                      ? '${settings.ratedWatts} W appliance power selected'
                      : 'Add your appliance power to enable estimates',
                  style: const TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 13,
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.lightText,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PowerPreset extends StatelessWidget {
  final String label;
  final int watts;
  final ValueChanged<int> onTap;

  const _PowerPreset({
    required this.label,
    required this.watts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: () => onTap(watts),
      avatar: const Icon(Icons.add_rounded, size: 16),
      label: Text(label),
      backgroundColor: AppTheme.surfaceSoft,
      side: BorderSide(color: AppTheme.outline),
      labelStyle: const TextStyle(
        color: AppTheme.primaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EstimateNotice extends StatelessWidget {
  const _EstimateNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is an estimate from the appliance wattage and selected time. This smart switch does not measure live voltage, current, or actual electricity usage.',
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
