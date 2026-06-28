class ScheduleItem {
  static const int allDaysMask = 127;
  static const int weekdaysMask = 62; // Mon–Fri
  static const int weekendMask = 65; // Sun + Sat

  static const List<String> dayShortNames = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  final String id;
  final String label;
  final bool enabled;
  final int onMinutes;
  final int offMinutes;
  final int daysMask;

  const ScheduleItem({
    required this.id,
    required this.label,
    required this.enabled,
    required this.onMinutes,
    required this.offMinutes,
    required this.daysMask,
  });

  factory ScheduleItem.empty(String id) {
    final number = int.tryParse(id.replaceFirst('s', '')) ?? 1;

    return ScheduleItem(
      id: id,
      label: 'Schedule $number',
      enabled: true,
      onMinutes: 8 * 60,
      offMinutes: 9 * 60,
      daysMask: allDaysMask,
    );
  }

  int get onHour => onMinutes ~/ 60;
  int get onMinute => onMinutes % 60;
  int get offHour => offMinutes ~/ 60;
  int get offMinute => offMinutes % 60;

  bool isEnabledOnDayIndex(int dayIndex) {
    if (dayIndex < 0 || dayIndex > 6) return false;
    return (daysMask & (1 << dayIndex)) != 0;
  }

  bool get hasAnyDaySelected => daysMask != 0;

  String get daysSummary {
    if (daysMask == allDaysMask) return 'Every day';
    if (daysMask == weekdaysMask) return 'Mon–Fri';
    if (daysMask == weekendMask) return 'Weekend';

    final labels = <String>[];

    for (var index = 0; index < dayShortNames.length; index++) {
      if (isEnabledOnDayIndex(index)) {
        labels.add(dayShortNames[index]);
      }
    }

    return labels.isEmpty ? 'No days selected' : labels.join(', ');
  }

  ScheduleItem copyWith({
    String? id,
    String? label,
    bool? enabled,
    int? onMinutes,
    int? offMinutes,
    int? daysMask,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      onMinutes: onMinutes ?? this.onMinutes,
      offMinutes: offMinutes ?? this.offMinutes,
      daysMask: daysMask ?? this.daysMask,
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'enabled': enabled,
      'onMinutes': onMinutes,
      'offMinutes': offMinutes,
      'daysMask': daysMask,
      'label': label,
    };
  }

  factory ScheduleItem.fromMap(
      String id,
      Map<dynamic, dynamic> map,
      ) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final number = int.tryParse(id.replaceFirst('s', '')) ?? 1;
    final onMinutes = readInt(map['onMinutes']).clamp(0, 1439).toInt();
    final offMinutes = readInt(map['offMinutes']).clamp(0, 1439).toInt();
    final rawMask = readInt(map['daysMask']);

    return ScheduleItem(
      id: id,
      label: map['label']?.toString().trim().isNotEmpty == true
          ? map['label'].toString().trim()
          : 'Schedule $number',
      enabled: map['enabled'] == true,
      onMinutes: onMinutes,
      offMinutes: offMinutes,
      daysMask: rawMask == 0 ? allDaysMask : rawMask.clamp(0, allDaysMask).toInt(),
    );
  }
}

class ScheduleModel {
  final int revision;
  final Map<String, ScheduleItem> items;

  const ScheduleModel({
    required this.revision,
    required this.items,
  });

  static const ScheduleModel empty = ScheduleModel(
    revision: 0,
    items: const <String, ScheduleItem>{},
  );

  List<ScheduleItem> get orderedItems {
    final values = items.values.toList();

    values.sort((left, right) {
      int slotNumber(ScheduleItem item) {
        return int.tryParse(item.id.replaceFirst('s', '')) ?? 999;
      }

      return slotNumber(left).compareTo(slotNumber(right));
    });

    return values;
  }

  List<ScheduleItem> get activeItems {
    return orderedItems.where((item) => item.enabled).toList();
  }

  bool get enabled => activeItems.isNotEmpty;
  int get activeCount => activeItems.length;

  // Backward-compatible convenience getters for any old widgets.
  ScheduleItem? get firstActiveItem {
    return activeItems.isEmpty ? null : activeItems.first;
  }

  int get onHour => firstActiveItem?.onHour ?? 0;
  int get onMinute => firstActiveItem?.onMinute ?? 0;
  int get offHour => firstActiveItem?.offHour ?? 0;
  int get offMinute => firstActiveItem?.offMinute ?? 0;
  int get daysMask => firstActiveItem?.daysMask ?? ScheduleItem.allDaysMask;

  factory ScheduleModel.fromMap(Map<dynamic, dynamic> map) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final parsedItems = <String, ScheduleItem>{};

    // New multi-schedule structure.
    final rawItems = map['items'];
    if (rawItems is Map) {
      Map<dynamic, dynamic>.from(rawItems).forEach((key, value) {
        if (value is Map) {
          final item = ScheduleItem.fromMap(
            key.toString(),
            Map<dynamic, dynamic>.from(value),
          );

          parsedItems[item.id] = item;
        }
      });
    }

    // Legacy single-schedule structure is still readable until the user
    // saves schedules through the new app UI.
    if (parsedItems.isEmpty && map.containsKey('enabled')) {
      final hasOnMinutes = map.containsKey('onMinutes');
      final hasOffMinutes = map.containsKey('offMinutes');

      final onMinutes = hasOnMinutes
          ? readInt(map['onMinutes'])
          : readInt(map['onHour']) * 60 + readInt(map['onMinute']);

      final offMinutes = hasOffMinutes
          ? readInt(map['offMinutes'])
          : readInt(map['offHour']) * 60 + readInt(map['offMinute']);

      final rawMask = readInt(map['daysMask']);

      parsedItems['s1'] = ScheduleItem(
        id: 's1',
        label: map['label']?.toString().trim().isNotEmpty == true
            ? map['label'].toString().trim()
            : 'Schedule 1',
        enabled: map['enabled'] == true,
        onMinutes: onMinutes.clamp(0, 1439).toInt(),
        offMinutes: offMinutes.clamp(0, 1439).toInt(),
        daysMask: rawMask == 0
            ? ScheduleItem.allDaysMask
            : rawMask.clamp(0, ScheduleItem.allDaysMask).toInt(),
      );
    }

    return ScheduleModel(
      revision: readInt(map['revision']),
      items: parsedItems,
    );
  }
}
