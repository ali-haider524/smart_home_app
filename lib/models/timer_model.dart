class TimerModel {
  final bool enabled;
  final int durationMs;
  final int revision;
  final String label;

  const TimerModel({
    required this.enabled,
    required this.durationMs,
    required this.revision,
    required this.label,
  });

  /// Keeps the current UI compatible while the database moves to durationMs.
  int get durationMinutes => durationMs ~/ (60 * 1000);

  factory TimerModel.fromMap(Map<dynamic, dynamic> map) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawDurationMs = readInt(map['durationMs']);
    final rawDurationMinutes = readInt(map['durationMinutes']);

    return TimerModel(
      enabled: map['enabled'] == true,
      durationMs: rawDurationMs > 0
          ? rawDurationMs
          : rawDurationMinutes * 60 * 1000,
      revision: readInt(map['revision']),
      label: map['label']?.toString() ?? '',
    );
  }
}
