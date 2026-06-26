import 'channel_model.dart';
import 'schedule_model.dart';
import 'timer_model.dart';

class DeviceModel {
  final String id;

  /// Retained only for backward-compatible parsing. The app must not trust it.
  final bool online;
  final int lastSeen;
  final String firmwareVersion;
  final String model;
  final int channelCount;
  final String nickname;
  final Map<String, ChannelModel> channels;
  final Map<String, TimerModel> timers;
  final Map<String, ScheduleModel> schedules;

  DeviceModel({
    required this.id,
    required this.online,
    required this.lastSeen,
    required this.firmwareVersion,
    required this.model,
    required this.channelCount,
    required this.nickname,
    required this.channels,
    required this.timers,
    required this.schedules,
  });

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory DeviceModel.fromMap(
      String id,
      Map<dynamic, dynamic> data, {
        String? nickname,
      }) {
    final parsedChannels = <String, ChannelModel>{};
    final parsedTimers = <String, TimerModel>{};
    final parsedSchedules = <String, ScheduleModel>{};

    if (data['channels'] is Map) {
      Map<dynamic, dynamic>.from(data['channels']).forEach((key, value) {
        if (value is Map) {
          parsedChannels[key.toString()] = ChannelModel.fromMap(
            key.toString(),
            Map<dynamic, dynamic>.from(value),
          );
        }
      });
    }

    if (data['timers'] is Map) {
      Map<dynamic, dynamic>.from(data['timers']).forEach((key, value) {
        if (value is Map) {
          parsedTimers[key.toString()] = TimerModel.fromMap(
            Map<dynamic, dynamic>.from(value),
          );
        }
      });
    }

    if (data['schedules'] is Map) {
      Map<dynamic, dynamic>.from(data['schedules']).forEach((key, value) {
        if (value is Map) {
          parsedSchedules[key.toString()] = ScheduleModel.fromMap(
            Map<dynamic, dynamic>.from(value),
          );
        }
      });
    }

    return DeviceModel(
      id: id,
      online: data['online'] == true,
      lastSeen: _readInt(data['lastSeen']),
      firmwareVersion: data['firmwareVersion']?.toString() ?? 'Unknown',
      model: data['model']?.toString() ?? 'SW1',
      channelCount: _readInt(data['channelCount']) == 0
          ? 1
          : _readInt(data['channelCount']),
      nickname: (nickname == null || nickname.trim().isEmpty)
          ? 'Smart Switch'
          : nickname.trim(),
      channels: parsedChannels,
      timers: parsedTimers,
      schedules: parsedSchedules,
    );
  }

  /// Firebase server timestamps are milliseconds since epoch.
  /// The ESP sends a heartbeat every ~10 seconds, so 35 seconds is a safe
  /// online window that does not rely on the old /online boolean.
  bool get isOnline {
    if (lastSeen <= 0) return false;

    final difference =
        DateTime.now().millisecondsSinceEpoch - lastSeen;

    return difference >= 0 && difference <= 35000;
  }

  String get lastSeenText {
    if (lastSeen <= 0) return 'Never seen';

    final differenceMs =
        DateTime.now().millisecondsSinceEpoch - lastSeen;

    if (differenceMs < 0) return 'Clock syncing';

    final seconds = differenceMs ~/ 1000;

    if (seconds < 5) return 'Just now';
    if (seconds < 60) return '$seconds sec ago';

    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min ago';

    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours hr ago';

    final days = hours ~/ 24;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
}
