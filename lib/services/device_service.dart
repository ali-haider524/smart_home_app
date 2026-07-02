import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/device_model.dart';
import '../models/schedule_model.dart';

/// Thrown when a device cannot be paired with the current account.
class DeviceClaimException implements Exception {
  final String message;

  const DeviceClaimException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a device maintenance request cannot be completed safely.
class DeviceMaintenanceException implements Exception {
  final String message;

  const DeviceMaintenanceException(this.message);

  @override
  String toString() => message;
}

/// Result returned by the pairing flow. Keeping this explicit prevents the
/// app from needlessly opening WiFi setup when a customer enters a product
/// that is already registered to the same account.
enum DeviceClaimOutcome {
  newlyRegistered,
  alreadyRegistered,
  restoredFromArchive,
}

class DeviceClaimResult {
  final DeviceClaimOutcome outcome;
  final String deviceId;
  final String nickname;

  const DeviceClaimResult({
    required this.outcome,
    required this.deviceId,
    required this.nickname,
  });

  bool get needsWiFiSetup => outcome == DeviceClaimOutcome.newlyRegistered;

  String get message {
    switch (outcome) {
      case DeviceClaimOutcome.newlyRegistered:
        return 'Device registered successfully. Continue with WiFi setup.';
      case DeviceClaimOutcome.alreadyRegistered:
        return 'This device is already registered in your account.';
      case DeviceClaimOutcome.restoredFromArchive:
        return 'This device was restored to My Devices.';
    }
  }
}

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

  String _normalizeDeviceId(String value) => value.trim().toUpperCase();

  String _normalizeClaimCode(String value) => value.trim().toUpperCase();

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Active devices shown on the dashboard.
  ///
  /// Phase 5A-2 security-read preparation:
  /// 1. Read the current user's own device mapping at /users/{uid}/devices.
  /// 2. Subscribe only to each mapped device at /devices/{deviceId}.
  ///
  /// This intentionally never listens to the complete /devices tree. Keeping
  /// reads at individual device paths prepares the app for per-device RTDB
  /// rules later, without changing the stable ESP command/timer/schedule
  /// database contract today.
  Stream<List<DeviceModel>> listenAllDevices() {
    return _listenMappedDevices(includeActive: true);
  }

  /// Archived devices remain linked to the current account, but use the same
  /// least-read pattern as active devices: mapping first, then individual
  /// device subscriptions only.
  Stream<List<DeviceModel>> listenArchivedDevices() {
    return _listenMappedDevices(includeActive: false);
  }

  Stream<List<DeviceModel>> _listenMappedDevices({
    required bool includeActive,
  }) {
    final uid = currentUid;

    if (uid == null) {
      return Stream.value(<DeviceModel>[]);
    }

    final controller = StreamController<List<DeviceModel>>.broadcast();
    StreamSubscription<DatabaseEvent>? userDeviceSubscription;
    final deviceSubscriptions = <String, StreamSubscription<DatabaseEvent>>{};
    final deviceDataById = <String, Map<dynamic, dynamic>>{};
    var nicknamesById = <String, String>{};
    var cancelled = false;

    void emitError(Object error, StackTrace stackTrace) {
      if (!cancelled && !controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    }

    void emitDevices() {
      if (cancelled || controller.isClosed) {
        return;
      }

      final devices = <DeviceModel>[];

      for (final entry in nicknamesById.entries) {
        final deviceData = deviceDataById[entry.key];

        // A mapped device can be offline or temporarily unavailable in the
        // database. Do not remove its user mapping; just wait for its own
        // individual listener to provide data again.
        if (deviceData == null) {
          continue;
        }

        devices.add(
          DeviceModel.fromMap(
            entry.key,
            deviceData,
            nickname: entry.value,
          ),
        );
      }

      devices.sort((left, right) => left.nickname.compareTo(right.nickname));
      controller.add(devices);
    }

    Map<String, String> parseRelevantDeviceMappings(dynamic value) {
      final result = <String, String>{};

      if (value is! Map) {
        return result;
      }

      final mappings = Map<dynamic, dynamic>.from(value);

      mappings.forEach((deviceId, mappingValue) {
        final id = deviceId.toString().trim();

        if (id.isEmpty) {
          return;
        }

        // Legacy mapping format: /users/{uid}/devices/{deviceId} = true.
        // It represents an active device and remains supported.
        if (mappingValue == true) {
          if (includeActive) {
            result[id] = 'Smart Switch';
          }
          return;
        }

        if (mappingValue is! Map) {
          return;
        }

        final mapping = Map<dynamic, dynamic>.from(mappingValue);
        final isActive = mapping['active'] != false;

        if (isActive != includeActive) {
          return;
        }

        final nickname = mapping['nickname']?.toString().trim();
        result[id] = (nickname == null || nickname.isEmpty)
            ? 'Smart Switch'
            : nickname;
      });

      return result;
    }

    void startDeviceSubscription(String deviceId) {
      if (deviceSubscriptions.containsKey(deviceId) || cancelled) {
        return;
      }

      final subscription = _devicesRef.child(deviceId).onValue.listen(
            (deviceEvent) {
          // A stale callback may arrive just after an archive/restore mapping
          // update. Ignore it unless this device is still in the current view.
          if (cancelled || !nicknamesById.containsKey(deviceId)) {
            return;
          }

          final value = deviceEvent.snapshot.value;

          if (value is Map) {
            deviceDataById[deviceId] = Map<dynamic, dynamic>.from(value);
          } else {
            deviceDataById.remove(deviceId);
          }

          emitDevices();
        },
        onError: (Object error, StackTrace stackTrace) {
          emitError(error, stackTrace);
        },
      );

      deviceSubscriptions[deviceId] = subscription;
    }

    void applyMappings(dynamic value) {
      if (cancelled) {
        return;
      }

      final nextNicknames = parseRelevantDeviceMappings(value);
      final existingIds = deviceSubscriptions.keys.toSet();
      final nextIds = nextNicknames.keys.toSet();

      // Stop only removed device listeners. Existing device listeners stay
      // alive, so a rename or archive-state change does not resubscribe to the
      // full database or interrupt other devices.
      for (final deviceId in existingIds.difference(nextIds)) {
        final subscription = deviceSubscriptions.remove(deviceId);
        if (subscription != null) {
          unawaited(subscription.cancel());
        }
        deviceDataById.remove(deviceId);
      }

      nicknamesById = nextNicknames;

      for (final deviceId in nextIds.difference(existingIds)) {
        startDeviceSubscription(deviceId);
      }

      // Immediately reflect archive/restore/rename mapping changes. Each
      // device listener then fills or refreshes its own live data.
      emitDevices();
    }

    userDeviceSubscription = _usersRef.child(uid).child('devices').onValue.listen(
          (userEvent) {
        applyMappings(userEvent.snapshot.value);
      },
      onError: (Object error, StackTrace stackTrace) {
        emitError(error, stackTrace);
      },
    );

    controller.onCancel = () async {
      cancelled = true;

      await userDeviceSubscription?.cancel();
      await Future.wait(
        deviceSubscriptions.values.map((subscription) => subscription.cancel()),
      );

      deviceSubscriptions.clear();
      deviceDataById.clear();
      nicknamesById = <String, String>{};
    };

    return controller.stream;
  }

  /// Single-device listener used by control, WiFi-setup, and settings screens.
  /// It already listens to one exact device path and never reads /devices.
  Stream<DeviceModel?> listenDevice(String deviceId) {
    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    return _devicesRef.child(normalizedDeviceId).onValue.map((event) {
      final value = event.snapshot.value;

      if (value == null || value is! Map) {
        return null;
      }

      return DeviceModel.fromMap(
        normalizedDeviceId,
        Map<dynamic, dynamic>.from(value),
      );
    });
  }

  /// Pairs a device to the signed-in user after checking the printed claim
  /// code and product lifecycle status.
  ///
  /// This is still a client-side MVP flow while Firebase Rules are in
  /// development mode. It provides correct app behavior and messages, but the
  /// production claim must later move to a trusted backend / Cloud Function.
  Future<DeviceClaimResult> claimDeviceForCurrentUser({
    required String deviceId,
    required String claimCode,
    required String nickname,
  }) async {
    final uid = currentUid;

    if (uid == null) {
      throw const DeviceClaimException('Please log in before pairing a device.');
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final normalizedClaimCode = _normalizeClaimCode(claimCode);
    final requestedNickname =
    nickname.trim().isEmpty ? 'Smart Switch' : nickname.trim();

    if (normalizedDeviceId.length < 6) {
      throw const DeviceClaimException('Enter a valid Device ID.');
    }

    if (normalizedClaimCode.length < 4) {
      throw const DeviceClaimException(
        'Enter the claim code printed on the device.',
      );
    }

    final snapshots = await Future.wait<DataSnapshot>([
      _devicesRef.child(normalizedDeviceId).get(),
      _usersRef.child(uid).child('devices').child(normalizedDeviceId).get(),
    ]);

    final deviceSnapshot = snapshots[0];
    final userMappingSnapshot = snapshots[1];

    if (!deviceSnapshot.exists || deviceSnapshot.value is! Map) {
      throw const DeviceClaimException(
        'Device not found. Check the Device ID and try again.',
      );
    }

    final device = Map<dynamic, dynamic>.from(deviceSnapshot.value as Map);
    final claimed = device['claimed'] == true;
    final ownerUid = device['ownerUid']?.toString() ?? '';
    final storedClaimCode =
    _normalizeClaimCode(device['claimCode']?.toString() ?? '');

    if (storedClaimCode.isEmpty ||
        storedClaimCode != normalizedClaimCode) {
      throw const DeviceClaimException('Claim code is incorrect.');
    }

    final activation = device['activation'] is Map
        ? Map<dynamic, dynamic>.from(device['activation'] as Map)
        : <dynamic, dynamic>{};

    final activationStatus =
        activation['status']?.toString().trim().toLowerCase() ?? '';

    if (activationStatus == 'blocked' ||
        activationStatus == 'not_sold' ||
        activationStatus == 'disabled') {
      throw const DeviceClaimException(
        'This device is not eligible for activation. Contact Easy Home Control support.',
      );
    }

    if (claimed && ownerUid.isNotEmpty && ownerUid != uid) {
      throw const DeviceClaimException(
        'This device is already linked to another account.',
      );
    }

    final userMapping = userMappingSnapshot.value is Map
        ? Map<dynamic, dynamic>.from(userMappingSnapshot.value as Map)
        : <dynamic, dynamic>{};

    final mappingExists = userMappingSnapshot.exists;
    final mappingIsActive = mappingExists && userMapping['active'] != false;
    final existingNickname =
        userMapping['nickname']?.toString().trim() ?? '';

    // Already owned by the same account: never force the customer through
    // WiFi setup again. If it was archived, restore it safely instead.
    if (claimed && ownerUid == uid && mappingExists) {
      if (!mappingIsActive) {
        await _usersRef.child(uid).child('devices').child(normalizedDeviceId).update({
          'active': true,
          'restoredAt': ServerValue.timestamp,
        });

        return DeviceClaimResult(
          outcome: DeviceClaimOutcome.restoredFromArchive,
          deviceId: normalizedDeviceId,
          nickname: existingNickname.isEmpty
              ? requestedNickname
              : existingNickname,
        );
      }

      return DeviceClaimResult(
        outcome: DeviceClaimOutcome.alreadyRegistered,
        deviceId: normalizedDeviceId,
        nickname: existingNickname.isEmpty ? requestedNickname : existingNickname,
      );
    }

    // Ownership already exists but this account's shortcut was removed outside
    // the normal archive flow. Restore only the shortcut; do not reopen WiFi
    // setup or rewrite device ownership.
    if (claimed && ownerUid == uid && !mappingExists) {
      await _usersRef.child(uid).child('devices').child(normalizedDeviceId).set({
        'role': 'owner',
        'nickname': requestedNickname,
        'active': true,
        'addedAt': ServerValue.timestamp,
        'restoredAt': ServerValue.timestamp,
      });

      return DeviceClaimResult(
        outcome: DeviceClaimOutcome.alreadyRegistered,
        deviceId: normalizedDeviceId,
        nickname: requestedNickname,
      );
    }

    final rootUpdates = <String, dynamic>{
      'devices/$normalizedDeviceId/claimed': true,
      'devices/$normalizedDeviceId/ownerUid': uid,
      'devices/$normalizedDeviceId/claimedAt': ServerValue.timestamp,
      'users/$uid/devices/$normalizedDeviceId': {
        'role': 'owner',
        'nickname': requestedNickname,
        'active': true,
        'addedAt': ServerValue.timestamp,
        'restoredAt': ServerValue.timestamp,
      },
    };

    // Existing legacy products do not have activation data. We create it at
    // first registration while preserving future factory-set warranty fields.
    if (activationStatus.isEmpty || activationStatus == 'eligible') {
      rootUpdates['devices/$normalizedDeviceId/activation/status'] = 'active';
      rootUpdates['devices/$normalizedDeviceId/activation/activatedAt'] =
          ServerValue.timestamp;
      rootUpdates['devices/$normalizedDeviceId/activation/activatedBy'] = uid;
    }

    await _database.ref().update(rootUpdates);

    return DeviceClaimResult(
      outcome: DeviceClaimOutcome.newlyRegistered,
      deviceId: normalizedDeviceId,
      nickname: requestedNickname,
    );
  }

  /// Retained for legacy flows. New pairing should use
  /// [claimDeviceForCurrentUser] so ownership and user mapping stay aligned.
  Future<void> addDeviceToCurrentUser({
    required String deviceId,
    String role = 'owner',
    String nickname = 'Smart Switch',
  }) async {
    final uid = currentUid;

    if (uid == null) {
      throw Exception('User not logged in');
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    await _usersRef.child(uid).child('devices').child(normalizedDeviceId).set({
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
    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    await _devicesRef
        .child(normalizedDeviceId)
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

    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    await _devicesRef
        .child(normalizedDeviceId)
        .child('timers')
        .child(channelId)
        .update({
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
    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    return _devicesRef
        .child(normalizedDeviceId)
        .child('timers')
        .child(channelId)
        .update({
      'enabled': false,
      'durationMs': 0,
      'revision': _nextRequestId(),
      'label': '',
      'cancelledAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
  }

  /// Saves all recurring weekly schedules in one atomic node replacement.
  ///
  /// ESP firmware supports six fixed slots: s1 through s6. Replacing the
  /// complete schedule node also removes deleted schedules safely.
  Future<void> saveSchedules({
    required String deviceId,
    required String channelId,
    required List<ScheduleItem> items,
  }) async {
    if (items.length > 6) {
      throw ArgumentError('A channel supports a maximum of 6 schedules.');
    }

    final slotMap = <String, dynamic>{};
    final usedIds = <String>{};

    for (final item in items) {
      final id = item.id.trim();

      if (!RegExp(r'^s[1-6]$').hasMatch(id)) {
        throw ArgumentError('Invalid schedule slot: $id');
      }

      if (!usedIds.add(id)) {
        throw ArgumentError('Schedule slots must be unique.');
      }

      if (item.onMinutes < 0 ||
          item.onMinutes > 1439 ||
          item.offMinutes < 0 ||
          item.offMinutes > 1439) {
        throw ArgumentError('Schedule time is invalid.');
      }

      if (item.enabled && item.daysMask == 0) {
        throw ArgumentError('Choose at least one day for every enabled schedule.');
      }

      if (item.enabled && item.onMinutes == item.offMinutes) {
        throw ArgumentError('ON and OFF time cannot be the same.');
      }

      slotMap[id] = item.toFirebaseMap();
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    await _devicesRef
        .child(normalizedDeviceId)
        .child('schedules')
        .child(channelId)
        .set({
      'revision': _nextRequestId(),
      'items': slotMap,
      'updatedAt': ServerValue.timestamp,
    });
  }

  /// Compatibility method for older call sites. It saves one schedule in s1
  /// using the new stable multi-schedule data contract.
  Future<void> saveDailySchedule({
    required String deviceId,
    required String channelId,
    required int onHour,
    required int onMinute,
    required int offHour,
    required int offMinute,
    int daysMask = ScheduleItem.allDaysMask,
  }) {
    return saveSchedules(
      deviceId: deviceId,
      channelId: channelId,
      items: [
        ScheduleItem(
          id: 's1',
          label: 'Schedule 1',
          enabled: true,
          onMinutes: onHour * 60 + onMinute,
          offMinutes: offHour * 60 + offMinute,
          daysMask: daysMask,
        ),
      ],
    );
  }

  Future<void> cancelSchedule({
    required String deviceId,
    required String channelId,
  }) {
    return saveSchedules(
      deviceId: deviceId,
      channelId: channelId,
      items: const [],
    );
  }

  /// Renames only the current user's shortcut. The device-wide record is not
  /// changed because each shared user may prefer a different nickname.
  Future<void> renameDeviceForCurrentUser({
    required String deviceId,
    required String nickname,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException('Please log in before renaming a device.');
    }

    final cleanName = nickname.trim();
    if (cleanName.isEmpty || cleanName.length > 40) {
      throw const DeviceMaintenanceException('Device name must be 1 to 40 characters.');
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final userDeviceRef = _usersRef.child(uid).child('devices').child(normalizedDeviceId);

    final mapping = await userDeviceRef.get();
    if (!mapping.exists) {
      throw const DeviceMaintenanceException('This device is no longer in your device list.');
    }

    await userDeviceRef.update({
      'nickname': cleanName,
      'renamedAt': ServerValue.timestamp,
    });
  }

  /// Archives only the current user's shortcut. It never changes device
  /// ownership, WiFi credentials, firmware, timers, schedules, or relay data.
  /// The user can restore the device later from Archived Devices.
  Future<void> archiveDeviceForCurrentUser({
    required String deviceId,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException('Please log in before removing a device.');
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final userDeviceRef = _usersRef.child(uid).child('devices').child(normalizedDeviceId);
    final mapping = await userDeviceRef.get();

    if (!mapping.exists) {
      throw const DeviceMaintenanceException('This device is no longer in your device list.');
    }

    await userDeviceRef.update({
      'active': false,
      'archivedAt': ServerValue.timestamp,
    });
  }

  /// Backward-compatible alias used by the existing settings screen.
  Future<void> removeDeviceFromCurrentUser({
    required String deviceId,
  }) {
    return archiveDeviceForCurrentUser(deviceId: deviceId);
  }

  /// Restores an archived device shortcut for the same account.
  Future<void> restoreArchivedDeviceForCurrentUser({
    required String deviceId,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException('Please log in before restoring a device.');
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final userDeviceRef = _usersRef.child(uid).child('devices').child(normalizedDeviceId);
    final mapping = await userDeviceRef.get();

    if (!mapping.exists) {
      throw const DeviceMaintenanceException('This archived device record no longer exists.');
    }

    await userDeviceRef.update({
      'active': true,
      'restoredAt': ServerValue.timestamp,
    });
  }

  /// Sends a one-time WiFi-reset request to the device. The ESP independently
  /// acknowledges this request before clearing only its saved WiFi credentials
  /// and rebooting into provisioning mode.
  Future<int> requestWiFiReset({
    required String deviceId,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException('Please log in before changing WiFi.');
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final requestId = _nextRequestId();

    await _devicesRef
        .child(normalizedDeviceId)
        .child('maintenance')
        .child('resetWifi')
        .update({
      'id': requestId,
      'requested': true,
      'requestedAt': ServerValue.timestamp,
      'requestedBy': uid,
    });

    return requestId;
  }

  /// Waits for the exact reset request acknowledgement. It listens only to a
  /// Firebase stream and performs no polling loop in the Flutter UI.
  Future<bool> waitForWiFiResetAcknowledgement({
    required String deviceId,
    required int requestId,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final resetRef = _devicesRef
        .child(normalizedDeviceId)
        .child('maintenance')
        .child('resetWifi');

    bool isAcknowledged(dynamic value) {
      if (value is! Map) return false;
      final data = Map<dynamic, dynamic>.from(value);
      return _readInt(data['ackId']) == requestId &&
          data['requested'] == false;
    }

    // Check once first in case the ESP acknowledged just before subscription.
    final initial = await resetRef.get();
    if (isAcknowledged(initial.value)) {
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<DatabaseEvent> subscription;
    late final Timer timer;

    subscription = resetRef.onValue.listen(
          (event) {
        if (isAcknowledged(event.snapshot.value) && !completer.isCompleted) {
          completer.complete(true);
        }
      },
      onError: (_) {
        // Keep waiting until timeout. A short network interruption should not
        // turn a valid reset request into an immediate failure.
      },
    );

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

}
