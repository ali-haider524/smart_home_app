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

  /// Device-wide registration data. These values are informational in the
  /// current client-side MVP and become server-enforced in the future backend
  /// security phase.
  final bool claimed;
  final String ownerUid;
  final String activationStatus;
  final int activatedAt;
  final int warrantyUntil;

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
    required this.claimed,
    required this.ownerUid,
    required this.activationStatus,
    required this.activatedAt,
    required this.warrantyUntil,
    required this.channels,
    required this.timers,
    required this.schedules,
  });

  static const int _onlineWindowMs = 45000;
  static const int _allowedFutureSkewMs = 5000;

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

    final activation = data['activation'] is Map
        ? Map<dynamic, dynamic>.from(data['activation'] as Map)
        : <dynamic, dynamic>{};

    final parsedActivationStatus =
        activation['status']?.toString().trim().toLowerCase() ?? '';

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
      claimed: data['claimed'] == true,
      ownerUid: data['ownerUid']?.toString() ?? '',
      activationStatus: parsedActivationStatus,
      activatedAt: _readInt(activation['activatedAt']),
      warrantyUntil: _readInt(activation['warrantyUntil']),
      channels: parsedChannels,
      timers: parsedTimers,
      schedules: parsedSchedules,
    );
  }

  /// Firebase server timestamps are milliseconds since epoch.
  /// The ESP heartbeat is about every 10 seconds. A 45-second window avoids
  /// false offline badges during network delay/reconnect. Firebase's server
  /// clock can be a little ahead of the phone clock, so permit 5 seconds of
  /// future skew instead of momentarily showing the device offline.
  bool get isOnline {
    if (lastSeen <= 0) return false;

    final ageMs = DateTime.now().millisecondsSinceEpoch - lastSeen;

    return ageMs >= -_allowedFutureSkewMs && ageMs <= _onlineWindowMs;
  }

  String get lastSeenText {
    if (lastSeen <= 0) return 'Never seen';

    final rawAgeMs = DateTime.now().millisecondsSinceEpoch - lastSeen;
    final ageMs = rawAgeMs < 0 ? 0 : rawAgeMs;
    final seconds = ageMs ~/ 1000;

    if (seconds < 5) return 'Just now';
    if (seconds < 60) return '$seconds sec ago';

    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min ago';

    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours hr ago';

    final days = hours ~/ 24;
    return '$days day${days == 1 ? '' : 's'} ago';
  }

  /// Human-readable lifecycle label for Device Settings.
  ///
  /// Older test devices may not have an `activation` node. If the device is
  /// already claimed, the app still treats it as a registered legacy device.
  String get registrationLabel {
    switch (activationStatus) {
      case 'eligible':
        return 'Ready to activate';
      case 'active':
        return 'Registered';
      case 'blocked':
      case 'disabled':
        return 'Activation blocked';
      case 'not_sold':
        return 'Not activated for sale';
      default:
        return claimed && ownerUid.isNotEmpty
            ? 'Registered'
            : 'Not registered';
    }
  }

  String get registrationDetail {
    switch (activationStatus) {
      case 'eligible':
        return 'This product can be paired with its printed claim code.';
      case 'active':
        return 'This product is registered to its current owner.';
      case 'blocked':
      case 'disabled':
        return 'Contact Easy Home Control support for this product.';
      case 'not_sold':
        return 'This product is not yet marked eligible for activation.';
      default:
        return claimed && ownerUid.isNotEmpty
            ? 'This is a legacy registered product.'
            : 'Pair this product using its Device ID and claim code.';
    }
  }

  bool get registrationNeedsAttention =>
      activationStatus == 'blocked' ||
          activationStatus == 'disabled' ||
          activationStatus == 'not_sold';

  bool get isRegistered => claimed && ownerUid.isNotEmpty;

}
