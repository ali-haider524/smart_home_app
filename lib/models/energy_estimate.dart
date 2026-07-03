/// User-provided values used only for an approximate energy calculation.
///
/// These values are stored under the current user's own device shortcut, not
/// under the ESP device record. They never influence relay control, timers,
/// schedules, Wi-Fi, or firmware behaviour.
class EnergyEstimateSettings {
  final int ratedWatts;
  final double unitRate;

  const EnergyEstimateSettings({
    required this.ratedWatts,
    required this.unitRate,
  });

  static const EnergyEstimateSettings empty = EnergyEstimateSettings(
    ratedWatts: 0,
    unitRate: 0,
  );

  bool get isConfigured => ratedWatts > 0;
  bool get hasUnitRate => unitRate > 0;

  factory EnergyEstimateSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return EnergyEstimateSettings.empty;
    }

    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return EnergyEstimateSettings(
      ratedWatts: readInt(map['ratedWatts']),
      unitRate: readDouble(map['unitRate']),
    );
  }

  EnergyEstimate estimateForMinutes(int minutes) {
    final safeMinutes = minutes < 1 ? 1 : minutes;
    final kilowattHours = ratedWatts * safeMinutes / 60000.0;

    return EnergyEstimate(
      minutes: safeMinutes,
      ratedWatts: ratedWatts,
      kilowattHours: kilowattHours,
      estimatedCost: hasUnitRate ? kilowattHours * unitRate : null,
    );
  }
}

/// Presentation-only result. This is deliberately not called "measured" or
/// "actual" because the current switch hardware does not contain a power meter.
class EnergyEstimate {
  final int minutes;
  final int ratedWatts;
  final double kilowattHours;
  final double? estimatedCost;

  const EnergyEstimate({
    required this.minutes,
    required this.ratedWatts,
    required this.kilowattHours,
    required this.estimatedCost,
  });

  String get energyLabel {
    if (kilowattHours < 0.01) {
      return '${(kilowattHours * 1000).toStringAsFixed(0)} Wh';
    }

    return '${kilowattHours.toStringAsFixed(kilowattHours < 1 ? 2 : 1)} kWh';
  }

  String? get costLabel {
    final cost = estimatedCost;
    if (cost == null) return null;

    return 'Rs. ${cost.toStringAsFixed(cost < 100 ? 1 : 0)}';
  }
}
