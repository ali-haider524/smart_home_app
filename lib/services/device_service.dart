import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/device_model.dart';

/// Firebase contract used by the stable ESP firmware:
///
/// Flutter writes:  /devices/{deviceId}/channels/{channelId}/command
/// ESP reads:       /devices/{deviceId}/channels/{channelId}/command
/// ESP writes:      /devices/{deviceId}/channels/{channelId}/state
///                  /devices/{deviceId}/channels/{channelId}/status
///                  /devices/{deviceId}/lastSeen
///
/// Do not write directly to /state from Flutter. That was the old echo-loop
/// path and is intentionally removed from this service.
class DeviceService {
  DeviceService();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    'https://easyhomecontrol-1-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  int _requestSequence =
  DateTime.now().millisecondsSinceEpoch.remainder(2000000000);

  DatabaseReference get _devicesRef => _database.ref('devices');
  DatabaseReference get _usersRef => _database.ref('users');

  String? get currentUid => _auth.currentUser?.uid;

  int _nextRequestId() {
    _requestSequence++;

    if (_requestSequence >= 2000000000) {
      _requestSequence = 1;
    }

    return _requestSequence;
  }

  Stream<List<DeviceModel>> listenAllDevices() {
    final uid = currentUid;

    if (uid == null) {
      return Stream.value(<DeviceModel>[]);
    }

    final controller = StreamController<List<DeviceModel>>.broadcast();

    StreamSubscription<DatabaseEvent>? userDeviceSub;
    StreamSubscription<DatabaseEvent>? allDevicesSub;

    userDeviceSub = _usersRef.child(uid).child('devices').onValue.listen(
          (userEvent) {
        final allowedDeviceIds = <String>{};
        final nicknames = <String, String>{};
        final userDeviceValue = userEvent.snapshot.value;

        if (userDeviceValue is Map) {
          final userDevices = Map<dynamic, dynamic>.from(userDeviceValue);

          userDevices.forEach((deviceId, value) {
            final id = deviceId.toString();

            if (value is Map) {
              final deviceInfo = Map<dynamic, dynamic>.from(value);
              final active = deviceInfo['active'] != false;

              if (active) {
                allowedDeviceIds.add(id);
                nicknames[id] =
                    deviceInfo['nickname']?.toString() ?? 'Smart Switch';
              }
            } else if (value == true) {
              allowedDeviceIds.add(id);
              nicknames[id] = 'Smart Switch';
            }
          });
        }

        allDevicesSub?.cancel();

        if (allowedDeviceIds.isEmpty) {
          controller.add(<DeviceModel>[]);
          return;
        }

        allDevicesSub = _devicesRef.onValue.listen(
              (devicesEvent) {
            final devicesValue = devicesEvent.snapshot.value;

            if (devicesValue == null || devicesValue is! Map) {
              controller.add(<DeviceModel>[]);
              return;
            }

            final rawDevices = Map<dynamic, dynamic>.from(devicesValue);
            final devices = <DeviceModel>[];

            rawDevices.forEach((deviceId, deviceData) {
              final id = deviceId.toString();

              if (!allowedDeviceIds.contains(id) || deviceData is! Map) {
                return;
              }

              devices.add(
                DeviceModel.fromMap(
                  id,
                  Map<dynamic, dynamic>.from(deviceData),
                  nickname: nicknames[id],
                ),
              );
            });

            devices.sort((a, b) => a.nickname.compareTo(b.nickname));
            controller.add(devices);
          },
          onError: controller.addError,
        );
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await userDeviceSub?.cancel();
      await allDevicesSub?.cancel();
    };

    return controller.stream;
  }

  Stream<DeviceModel?> listenDevice(String deviceId) {
    return _devicesRef.child(deviceId).onValue.map((event) {
      final value = event.snapshot.value;

      if (value == null || value is! Map) {
        return null;
      }

      return DeviceModel.fromMap(
        deviceId,
        Map<dynamic, dynamic>.from(value),
      );
    });
  }

  Future<void> addDeviceToCurrentUser({
    required String deviceId,
    String role = 'owner',
    String nickname = 'Smart Switch',
  }) async {
    final uid = currentUid;

    if (uid == null) {
      throw Exception('User not logged in');
    }

    await _usersRef.child(uid).child('devices').child(deviceId).set({
      'role': role,
      'nickname': nickname,
      'active': true,
      'addedAt': ServerValue.timestamp,
    });
  }

  /// Sends a command object only. ESP is the sole writer of actual /state.
  Future<void> setChannelState({
    required String deviceId,
    required String channelId,
    required bool state,
  }) async {
    await _devicesRef
        .child(deviceId)
        .child('channels')
        .child(channelId)
        .child('command')
        .set({
      'id': _nextRequestId(),
      'state': state,
      'requestedAt': ServerValue.timestamp,
    });
  }

  Future<void> toggleChannel({
    required String deviceId,
    required String channelId,
    required bool currentState,
  }) {
    return setChannelState(
      deviceId: deviceId,
      channelId: channelId,
      state: !currentState,
    );
  }

  Future<void> startTimer({
    required String deviceId,
    required String channelId,
    required int durationMinutes,
    required String label,
  }) async {
    if (durationMinutes <= 0 || durationMinutes > 1440) {
      throw ArgumentError('Timer duration must be between 1 and 1440 minutes.');
    }

    await _devicesRef.child(deviceId).child('timers').child(channelId).update({
      'enabled': true,
      'durationMs': durationMinutes * 60 * 1000,
      'revision': _nextRequestId(),
      'label': label,
      'completedAt': null,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> cancelTimer({
    required String deviceId,
    required String channelId,
  }) {
    return _devicesRef.child(deviceId).child('timers').child(channelId).update({
      'enabled': false,
      'durationMs': 0,
      'revision': _nextRequestId(),
      'label': '',
      'cancelledAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> saveDailySchedule({
    required String deviceId,
    required String channelId,
    required int onHour,
    required int onMinute,
    required int offHour,
    required int offMinute,
    int daysMask = 127,
  }) {
    final onMinutes = onHour * 60 + onMinute;
    final offMinutes = offHour * 60 + offMinute;

    return _devicesRef.child(deviceId).child('schedules').child(channelId).set({
      'enabled': true,
      'onMinutes': onMinutes,
      'offMinutes': offMinutes,
      'daysMask': daysMask,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> cancelSchedule({
    required String deviceId,
    required String channelId,
  }) {
    return _devicesRef.child(deviceId).child('schedules').child(channelId).update({
      'enabled': false,
      'updatedAt': ServerValue.timestamp,
    });
  }
}
