class ScheduleModel {
  final bool enabled;
  final int onMinutes;
  final int offMinutes;
  final int daysMask;

  const ScheduleModel({
    required this.enabled,
    required this.onMinutes,
    required this.offMinutes,
    required this.daysMask,
  });

  // Compatibility getters used by your existing DeviceControlScreen UI.
  int get onHour => onMinutes ~/ 60;
  int get onMinute => onMinutes % 60;
  int get offHour => offMinutes ~/ 60;
  int get offMinute => offMinutes % 60;

  factory ScheduleModel.fromMap(Map<dynamic, dynamic> map) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final hasOnMinutes = map.containsKey('onMinutes');
    final hasOffMinutes = map.containsKey('offMinutes');

    final onMinutes = hasOnMinutes
        ? readInt(map['onMinutes'])
        : readInt(map['onHour']) * 60 + readInt(map['onMinute']);

    final offMinutes = hasOffMinutes
        ? readInt(map['offMinutes'])
        : readInt(map['offHour']) * 60 + readInt(map['offMinute']);

    return ScheduleModel(
      enabled: map['enabled'] == true,
      onMinutes: onMinutes.clamp(0, 1439).toInt(),
      offMinutes: offMinutes.clamp(0, 1439).toInt(),
      daysMask: readInt(map['daysMask']) == 0 ? 127 : readInt(map['daysMask']),
    );
  }
}
