import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/server_clock.dart';
import '../models/device_access.dart';
import '../models/device_model.dart';
import '../models/energy_estimate.dart';
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
  DeviceService() {
    ServerClock.instance.start(_database);
  }

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
  DatabaseReference get _deviceAccessRef => _database.ref('deviceAccess');
  DatabaseReference get _accessInvitesRef => _database.ref('accessInvites');

  String? get currentUid => _auth.currentUser?.uid;

  int _nextRequestId() {
    _requestSequence++;

    if (_requestSequence >= 2000000000) {
      _requestSequence = 1;
    }

    return _requestSequence;
  }

  String _normalizeDeviceId(String value) => value.trim().toUpperCase();

  String _normalizeClaimCode(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

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

  /// Claims an unregistered product for the signed-in user.
  ///
  /// Security foundation contract:
  /// - The app never reads a raw claim code from `/devices/{deviceId}`.
  /// - Factory provisioning stores the secret at `/deviceSecrets/{deviceId}`,
  ///   which clients cannot read.
  /// - A one-time, write-only receipt at `/claimRequests/{deviceId}/{uid}`
  ///   carries the printed code inside the same atomic update as ownership.
  /// - RTDB Rules compare that receipt with the private factory secret and
  ///   reject the entire update if it does not match.
  ///
  /// Existing owners can still restore or reopen their own device without
  /// entering the claim code. This preserves the stable archive/re-add flow.
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

    final userMapping = userMappingSnapshot.value is Map
        ? Map<dynamic, dynamic>.from(userMappingSnapshot.value as Map)
        : <dynamic, dynamic>{};

    final mappingExists = userMappingSnapshot.exists;
    final mappingIsActive = mappingExists && userMapping['active'] != false;
    final existingNickname = userMapping['nickname']?.toString().trim() ?? '';

    // Already owned by another account. Factory claim credentials must never
    // become a reusable household sharing password.
    if (claimed && ownerUid.isNotEmpty && ownerUid != uid) {
      throw const DeviceClaimException(
        'This device is already linked to another account. Ask the owner to share access or transfer ownership.',
      );
    }

    // Already owned by the same account: never require the printed code or
    // force Wi-Fi setup again. If the shortcut was archived, restore it.
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

    // Ownership exists but the current owner's personal shortcut was removed
    // outside the normal archive flow. Restore only that shortcut.
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

    // New owner claim. Factory codes are generated as long random values; the
    // app accepts the formatted value without exposing or reading the stored
    // factory secret from Firebase.
    if (normalizedClaimCode.length < 16) {
      throw const DeviceClaimException(
        'Enter the full claim code printed on the product label.',
      );
    }

    final rootUpdates = <String, dynamic>{
      // Write-only proof. RTDB Rules compare it with `/deviceSecrets` during
      // this same atomic update. No screen reads this node.
      'claimRequests/$normalizedDeviceId/$uid': {
        'claimCode': normalizedClaimCode,
        'requestedAt': ServerValue.timestamp,
      },
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
      // Device-wide account access remains outside the ESP operation tree.
      'deviceAccess/$normalizedDeviceId/$uid': {
        'role': 'owner',
        'addedAt': ServerValue.timestamp,
        'addedBy': uid,
        'displayLabel': _currentUserLabel(),
      },
    };

    // Existing legacy products may not have an activation node. Creating it
    // during the first valid claim keeps old stock compatible.
    if (activationStatus.isEmpty || activationStatus == 'eligible') {
      rootUpdates['devices/$normalizedDeviceId/activation/status'] = 'active';
      rootUpdates['devices/$normalizedDeviceId/activation/activatedAt'] =
          ServerValue.timestamp;
      rootUpdates['devices/$normalizedDeviceId/activation/activatedBy'] = uid;
    }

    try {
      await _database.ref().update(rootUpdates);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const DeviceClaimException(
          'Claim code is incorrect, the device is unavailable, or it was already claimed.',
        );
      }
      rethrow;
    }

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

  /// Reads optional, user-specific values used for an approximate energy
  /// calculation. The ESP device tree is intentionally not involved.
  Stream<EnergyEstimateSettings> listenEnergyEstimateSettings(String deviceId) {
    final uid = currentUid;
    if (uid == null) {
      return Stream.value(EnergyEstimateSettings.empty);
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    return _usersRef
        .child(uid)
        .child('devices')
        .child(normalizedDeviceId)
        .child('energyEstimate')
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return EnergyEstimateSettings.empty;
      }

      return EnergyEstimateSettings.fromMap(
        Map<dynamic, dynamic>.from(value),
      );
    });
  }

  /// Saves optional display preferences for estimated energy only.
  ///
  /// This method does not touch /devices/{deviceId}, so it cannot affect relay
  /// commands, firmware, timers, schedules, Wi-Fi setup, or device ownership.
  Future<void> saveEnergyEstimateSettings({
    required String deviceId,
    required int ratedWatts,
    required double unitRate,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please log in before saving energy settings.',
      );
    }

    if (ratedWatts < 1 || ratedWatts > 20000) {
      throw const DeviceMaintenanceException(
        'Appliance power must be between 1 and 20,000 watts.',
      );
    }

    if (unitRate < 0 || unitRate > 10000) {
      throw const DeviceMaintenanceException(
        'Enter a valid electricity price, or leave it empty.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final userDeviceRef =
    _usersRef.child(uid).child('devices').child(normalizedDeviceId);
    final mapping = await userDeviceRef.get();

    if (!mapping.exists) {
      throw const DeviceMaintenanceException(
        'This device is no longer in your device list.',
      );
    }

    await userDeviceRef.child('energyEstimate').update({
      'ratedWatts': ratedWatts,
      'unitRate': unitRate,
      'updatedAt': ServerValue.timestamp,
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


  /// Requests a non-destructive local Wi-Fi setup hotspot from an online
  /// device. The firmware acknowledges it without clearing saved credentials;
  /// replacement Wi-Fi is stored only after the ESP joins it successfully.
  Future<int> requestWiFiSetupMode({
    required String deviceId,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please log in before changing Wi-Fi.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final requestId = _nextRequestId();

    await _devicesRef
        .child(normalizedDeviceId)
        .child('maintenance')
        .child('openWifiSetup')
        .update({
      'id': requestId,
      'requested': true,
      'requestedAt': ServerValue.timestamp,
      'requestedBy': uid,
    });

    return requestId;
  }

  /// Waits for the exact non-destructive Wi-Fi setup acknowledgement from the
  /// ESP. This never polls the Flutter UI and does not touch resetWifi.
  Future<bool> waitForWiFiSetupModeAcknowledgement({
    required String deviceId,
    required int requestId,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final setupRef = _devicesRef
        .child(normalizedDeviceId)
        .child('maintenance')
        .child('openWifiSetup');

    bool isAcknowledged(dynamic value) {
      if (value is! Map) return false;
      final data = Map<dynamic, dynamic>.from(value);
      return _readInt(data['ackId']) == requestId &&
          data['requested'] == false;
    }

    final initial = await setupRef.get();
    if (isAcknowledged(initial.value)) {
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<DatabaseEvent> subscription;
    late final Timer timer;

    subscription = setupRef.onValue.listen(
          (event) {
        if (isAcknowledged(event.snapshot.value) && !completer.isCompleted) {
          completer.complete(true);
        }
      },
      onError: (_) {
        // The device may be switching into AP+STA mode. Keep waiting until the
        // requested timeout instead of failing on a short transient error.
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

  // -------------------------------------------------------------------------
  // Shared-home access
  // -------------------------------------------------------------------------
  // These account records live outside /devices/{id}. The ESP firmware never
  // reads or writes them, so sharing cannot alter the stable command, timer,
  // schedule, heartbeat, or Wi-Fi provisioning contract.

  String _normalizeInviteCode(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _currentUserLabel() {
    final email = _auth.currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    final phone = _auth.currentUser?.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) return phone;

    return 'Shared user';
  }

  String _generateInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final result = StringBuffer();

    // 20 base-32 characters provide roughly 100 bits of entropy. Hyphens are
    // presentation-only and are accepted by _normalizeInviteCode().
    for (var index = 0; index < 20; index++) {
      result.write(alphabet[random.nextInt(alphabet.length)]);
    }

    return result.toString();
  }

  Future<DeviceAccessInfo> getCurrentUserDeviceAccess(String deviceId) async {
    final uid = currentUid;
    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    if (uid == null) return DeviceAccessInfo.empty(normalizedDeviceId);

    final mappingSnapshot = await _usersRef
        .child(uid)
        .child('devices')
        .child(normalizedDeviceId)
        .get();

    if (!mappingSnapshot.exists) {
      return DeviceAccessInfo.empty(normalizedDeviceId);
    }

    if (mappingSnapshot.value is Map) {
      return DeviceAccessInfo.fromMap(
        normalizedDeviceId,
        Map<dynamic, dynamic>.from(mappingSnapshot.value as Map),
      );
    }

    // Legacy mappings used true. They are only owner mappings in the original
    // application contract, so retain that safe backward-compatible behavior.
    if (mappingSnapshot.value == true) {
      return DeviceAccessInfo(
        deviceId: normalizedDeviceId,
        role: DeviceAccessRole.owner,
        nickname: 'Smart Switch',
        active: true,
      );
    }

    return DeviceAccessInfo.empty(normalizedDeviceId);
  }

  Stream<DeviceAccessInfo> listenCurrentUserDeviceAccess(String deviceId) {
    final uid = currentUid;
    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    if (uid == null) {
      return Stream.value(DeviceAccessInfo.empty(normalizedDeviceId));
    }

    return _usersRef
        .child(uid)
        .child('devices')
        .child(normalizedDeviceId)
        .onValue
        .map((event) {
      final value = event.snapshot.value;

      if (value is Map) {
        return DeviceAccessInfo.fromMap(
          normalizedDeviceId,
          Map<dynamic, dynamic>.from(value),
        );
      }

      if (value == true) {
        return DeviceAccessInfo(
          deviceId: normalizedDeviceId,
          role: DeviceAccessRole.owner,
          nickname: 'Smart Switch',
          active: true,
        );
      }

      return DeviceAccessInfo.empty(normalizedDeviceId);
    });
  }

  Future<void> _requireCurrentUserOwner(String deviceId) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please sign in before managing device access.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final ownerSnapshot = await _devicesRef
        .child(normalizedDeviceId)
        .child('ownerUid')
        .get();

    if (ownerSnapshot.value?.toString() != uid) {
      throw const DeviceMaintenanceException(
        'Only the device owner can manage access or transfer ownership.',
      );
    }
  }

  /// Ensures legacy owner records have a matching access record. It is called
  /// only when the verified owner opens Manage access and does not touch the
  /// firmware device contract.
  Future<void> ensureCurrentOwnerAccessRecord(String deviceId) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please sign in before managing device access.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    await _requireCurrentUserOwner(normalizedDeviceId);

    final accessRef = _deviceAccessRef.child(normalizedDeviceId).child(uid);
    final existing = await accessRef.get();

    if (existing.exists) return;

    await accessRef.set({
      'role': 'owner',
      'addedAt': ServerValue.timestamp,
      'addedBy': uid,
      'displayLabel': _currentUserLabel(),
    });
  }

  Stream<List<DeviceAccessMember>> listenDeviceAccessMembers(String deviceId) {
    final normalizedDeviceId = _normalizeDeviceId(deviceId);

    return _deviceAccessRef.child(normalizedDeviceId).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <DeviceAccessMember>[];

      final members = <DeviceAccessMember>[];
      Map<dynamic, dynamic>.from(value).forEach((uid, item) {
        if (item is Map) {
          members.add(
            DeviceAccessMember.fromMap(
              uid.toString(),
              Map<dynamic, dynamic>.from(item),
            ),
          );
        }
      });

      members.sort((left, right) {
        if (left.isOwner != right.isOwner) return left.isOwner ? -1 : 1;
        return left.displayLabel.compareTo(right.displayLabel);
      });

      return members;
    });
  }

  DatabaseReference _ownerInvitePointersRef(String uid, String deviceId) {
    return _usersRef
        .child(uid)
        .child('devices')
        .child(deviceId)
        .child('accessInvitePointers');
  }

  /// Restores the owner's still-valid share or transfer code after this screen
  /// is reopened. The actual code remains stored server-side for its full
  /// lifetime; leaving the page never cancels it.
  Future<Map<DeviceInviteType, DeviceAccessInvite>>
  loadCurrentOwnerAccessInvites(String deviceId) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please sign in before managing device access.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    await _requireCurrentUserOwner(normalizedDeviceId);

    final pointersSnapshot =
    await _ownerInvitePointersRef(uid, normalizedDeviceId).get();
    if (pointersSnapshot.value is! Map) {
      return <DeviceInviteType, DeviceAccessInvite>{};
    }

    final pointerMap = Map<dynamic, dynamic>.from(pointersSnapshot.value as Map);
    final candidates = <DeviceInviteType, String>{};

    for (final type in DeviceInviteType.values) {
      final rawPointer = pointerMap[type.firebaseValue];
      if (rawPointer is! Map) continue;

      final pointer = Map<dynamic, dynamic>.from(rawPointer);
      final code = _normalizeInviteCode(pointer['code']?.toString() ?? '');
      if (code.length == 20) {
        candidates[type] = code;
      }
    }

    if (candidates.isEmpty) {
      return <DeviceInviteType, DeviceAccessInvite>{};
    }

    final snapshots = await Future.wait<DataSnapshot>(
      candidates.values.map((code) => _accessInvitesRef.child(code).get()),
    );

    final active = <DeviceInviteType, DeviceAccessInvite>{};
    final stalePointerUpdates = <String, dynamic>{};
    var index = 0;

    for (final entry in candidates.entries) {
      final snapshot = snapshots[index++];
      final type = entry.key;
      final code = entry.value;

      if (snapshot.value is! Map) {
        stalePointerUpdates[
        'users/$uid/devices/$normalizedDeviceId/accessInvitePointers/${type.firebaseValue}'] = null;
        continue;
      }

      final invite = DeviceAccessInvite.fromMap(
        code,
        Map<dynamic, dynamic>.from(snapshot.value as Map),
      );

      final keepInvite = invite.deviceId == normalizedDeviceId &&
          invite.createdBy == uid &&
          invite.type == type &&
          !invite.isExpired &&
          (invite.status == DeviceInviteStatus.pending ||
              (type == DeviceInviteType.transfer &&
                  invite.status == DeviceInviteStatus.accepted));

      if (keepInvite) {
        active[type] = invite;
      } else {
        stalePointerUpdates[
        'users/$uid/devices/$normalizedDeviceId/accessInvitePointers/${type.firebaseValue}'] = null;
      }
    }

    if (stalePointerUpdates.isNotEmpty) {
      await _database.ref().update(stalePointerUpdates);
    }

    return active;
  }

  Stream<DeviceAccessInvite?> listenDeviceAccessInvite(String inviteCode) {
    final cleanCode = _normalizeInviteCode(inviteCode);
    if (cleanCode.isEmpty) return Stream.value(null);

    return _accessInvitesRef.child(cleanCode).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return null;
      return DeviceAccessInvite.fromMap(
        cleanCode,
        Map<dynamic, dynamic>.from(value),
      );
    });
  }

  Future<DeviceAccessInvite> createDeviceAccessInvite({
    required String deviceId,
    required DeviceInviteType type,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please sign in before sharing a device.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    await ensureCurrentOwnerAccessRecord(normalizedDeviceId);

    // Reuse an active code so accidental navigation away from Manage access
    // never forces the owner to generate and resend another code.
    final existing = await loadCurrentOwnerAccessInvites(normalizedDeviceId);
    final existingInvite = existing[type];
    if (existingInvite != null) {
      return existingInvite;
    }

    final code = _generateInviteCode();
    final expiresAt = DateTime.now()
        .add(const Duration(minutes: 10))
        .millisecondsSinceEpoch;

    final invite = DeviceAccessInvite(
      code: code,
      deviceId: normalizedDeviceId,
      type: type,
      status: DeviceInviteStatus.pending,
      createdBy: uid,
      expiresAt: expiresAt,
      acceptedBy: '',
      recipientLabel: '',
    );

    await _database.ref().update({
      'accessInvites/$code': {
        'deviceId': normalizedDeviceId,
        'type': type.firebaseValue,
        'status': DeviceInviteStatus.pending.firebaseValue,
        'createdBy': uid,
        'createdAt': ServerValue.timestamp,
        'expiresAt': expiresAt,
      },
      'users/$uid/devices/$normalizedDeviceId/accessInvitePointers/${type.firebaseValue}': {
        'code': code,
        'type': type.firebaseValue,
        'expiresAt': expiresAt,
        'createdAt': ServerValue.timestamp,
      },
    });

    return invite;
  }

  Future<void> cancelDeviceAccessInvite(String inviteCode) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please sign in before cancelling this code.',
      );
    }

    final code = _normalizeInviteCode(inviteCode);
    if (code.isEmpty) return;

    final inviteRef = _accessInvitesRef.child(code);
    final snapshot = await inviteRef.get();
    if (snapshot.value is! Map) return;

    final invite = DeviceAccessInvite.fromMap(
      code,
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );

    if (invite.createdBy != uid) {
      throw const DeviceMaintenanceException(
        'Only the device owner can cancel this code.',
      );
    }

    final updates = <String, dynamic>{
      'users/$uid/devices/${invite.deviceId}/accessInvitePointers/${invite.type.firebaseValue}': null,
    };

    if (invite.status == DeviceInviteStatus.pending) {
      updates['accessInvites/$code/status'] =
          DeviceInviteStatus.cancelled.firebaseValue;
      updates['accessInvites/$code/cancelledAt'] = ServerValue.timestamp;
    }

    await _database.ref().update(updates);
  }

  Future<SharedDeviceJoinResult> joinSharedDeviceForCurrentUser({
    required String deviceId,
    required String inviteCode,
    required String nickname,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceClaimException(
        'Please log in before joining a shared device.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final code = _normalizeInviteCode(inviteCode);
    final requestedNickname =
    nickname.trim().isEmpty ? 'Smart Switch' : nickname.trim();

    if (normalizedDeviceId.length < 6) {
      throw const DeviceClaimException('Enter a valid Device ID.');
    }

    if (code.length != 20) {
      throw const DeviceClaimException('Enter the 20-character share code.');
    }

    final snapshots = await Future.wait<DataSnapshot>([
      _accessInvitesRef.child(code).get(),
      _usersRef.child(uid).child('devices').child(normalizedDeviceId).get(),
      _deviceAccessRef.child(normalizedDeviceId).child(uid).get(),
    ]);

    final inviteSnapshot = snapshots[0];
    final userMappingSnapshot = snapshots[1];
    final accessSnapshot = snapshots[2];

    if (inviteSnapshot.value is! Map) {
      throw const DeviceClaimException(
        'Share code was not found. Check it and try again.',
      );
    }

    final invite = DeviceAccessInvite.fromMap(
      code,
      Map<dynamic, dynamic>.from(inviteSnapshot.value as Map),
    );

    if (invite.deviceId != normalizedDeviceId) {
      throw const DeviceClaimException(
        'This code belongs to a different device.',
      );
    }

    if (invite.isExpired) {
      throw const DeviceClaimException(
        'This code has expired. Ask the owner for a new one.',
      );
    }

    if (invite.status != DeviceInviteStatus.pending) {
      if (invite.acceptedBy == uid && invite.type == DeviceInviteType.transfer) {
        return SharedDeviceJoinResult(
          outcome: SharedDeviceJoinOutcome.transferWaiting,
          deviceId: normalizedDeviceId,
          nickname: requestedNickname,
        );
      }

      throw const DeviceClaimException(
        'This code has already been used. Ask the owner for a new one.',
      );
    }

    // A user who already has access can restore an archived shortcut without
    // spending another one-time code.
    if (accessSnapshot.exists) {
      final existingMapping = userMappingSnapshot.value is Map
          ? Map<dynamic, dynamic>.from(userMappingSnapshot.value as Map)
          : <dynamic, dynamic>{};
      final existingNickname =
          existingMapping['nickname']?.toString().trim() ?? '';
      final wasArchived = userMappingSnapshot.exists &&
          existingMapping['active'] == false;

      if (wasArchived) {
        await _usersRef
            .child(uid)
            .child('devices')
            .child(normalizedDeviceId)
            .update({
          'active': true,
          'restoredAt': ServerValue.timestamp,
        });
      }

      return SharedDeviceJoinResult(
        outcome: wasArchived
            ? SharedDeviceJoinOutcome.restored
            : SharedDeviceJoinOutcome.alreadyAdded,
        deviceId: normalizedDeviceId,
        nickname: existingNickname.isEmpty ? requestedNickname : existingNickname,
      );
    }

    if (invite.type == DeviceInviteType.transfer) {
      await _accessInvitesRef.child(code).update({
        'status': DeviceInviteStatus.accepted.firebaseValue,
        'acceptedBy': uid,
        'acceptedAt': ServerValue.timestamp,
        'recipientLabel': _currentUserLabel(),
      });

      return SharedDeviceJoinResult(
        outcome: SharedDeviceJoinOutcome.transferWaiting,
        deviceId: normalizedDeviceId,
        nickname: requestedNickname,
      );
    }

    await _database.ref().update({
      'deviceAccess/$normalizedDeviceId/$uid': {
        'role': 'member',
        'addedAt': ServerValue.timestamp,
        'addedBy': invite.createdBy,
        'inviteCode': code,
        'displayLabel': _currentUserLabel(),
      },
      'users/$uid/devices/$normalizedDeviceId': {
        'role': 'member',
        'nickname': requestedNickname,
        'active': true,
        'addedAt': ServerValue.timestamp,
        'sharedAt': ServerValue.timestamp,
        'inviteCode': code,
      },
      'accessInvites/$code/status': DeviceInviteStatus.accepted.firebaseValue,
      'accessInvites/$code/acceptedBy': uid,
      'accessInvites/$code/acceptedAt': ServerValue.timestamp,
      'accessInvites/$code/recipientLabel': _currentUserLabel(),
    });

    return SharedDeviceJoinResult(
      outcome: SharedDeviceJoinOutcome.added,
      deviceId: normalizedDeviceId,
      nickname: requestedNickname,
    );
  }

  Future<void> removeSharedDeviceMember({
    required String deviceId,
    required String memberUid,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please sign in before managing device access.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    await ensureCurrentOwnerAccessRecord(normalizedDeviceId);

    if (memberUid == uid) {
      throw const DeviceMaintenanceException(
        'Ownership cannot be removed from this screen.',
      );
    }

    final targetSnapshot = await _deviceAccessRef
        .child(normalizedDeviceId)
        .child(memberUid)
        .get();

    if (targetSnapshot.value is! Map) {
      throw const DeviceMaintenanceException(
        'This shared member no longer has access.',
      );
    }

    final target = Map<dynamic, dynamic>.from(targetSnapshot.value as Map);
    if (DeviceAccessRole.fromValue(target['role']).isOwner) {
      throw const DeviceMaintenanceException(
        'Use ownership transfer to change the device owner.',
      );
    }

    await _database.ref().update({
      'deviceAccess/$normalizedDeviceId/$memberUid': null,
      'users/$memberUid/devices/$normalizedDeviceId': null,
    });
  }

  Future<void> completeOwnershipTransfer({
    required String deviceId,
    required String inviteCode,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const DeviceMaintenanceException(
        'Please sign in before transferring ownership.',
      );
    }

    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    final code = _normalizeInviteCode(inviteCode);
    await ensureCurrentOwnerAccessRecord(normalizedDeviceId);

    final snapshots = await Future.wait<DataSnapshot>([
      _accessInvitesRef.child(code).get(),
      _deviceAccessRef.child(normalizedDeviceId).get(),
    ]);

    if (snapshots[0].value is! Map) {
      throw const DeviceMaintenanceException('Transfer code is no longer available.');
    }

    final invite = DeviceAccessInvite.fromMap(
      code,
      Map<dynamic, dynamic>.from(snapshots[0].value as Map),
    );

    if (invite.type != DeviceInviteType.transfer ||
        invite.deviceId != normalizedDeviceId ||
        invite.createdBy != uid ||
        invite.status != DeviceInviteStatus.accepted ||
        invite.acceptedBy.trim().isEmpty) {
      throw const DeviceMaintenanceException(
        'The new owner has not accepted this transfer code yet.',
      );
    }

    final newOwnerUid = invite.acceptedBy;
    if (newOwnerUid == uid) {
      throw const DeviceMaintenanceException(
        'Choose a different account for ownership transfer.',
      );
    }

    final previousAccess = <String>{uid};
    if (snapshots[1].value is Map) {
      previousAccess.addAll(
        Map<dynamic, dynamic>.from(snapshots[1].value as Map)
            .keys
            .map((value) => value.toString()),
      );
    }

    final updates = <String, dynamic>{
      'devices/$normalizedDeviceId/ownerUid': newOwnerUid,
      'devices/$normalizedDeviceId/ownershipTransferredAt': ServerValue.timestamp,
      'devices/$normalizedDeviceId/ownershipTransferredBy': uid,
      'deviceAccess/$normalizedDeviceId': {
        newOwnerUid: {
          'role': 'owner',
          'addedAt': ServerValue.timestamp,
          'addedBy': uid,
          'transferInvite': code,
          'displayLabel': invite.recipientLabel.isEmpty
              ? 'New owner'
              : invite.recipientLabel,
        },
      },
      'users/$newOwnerUid/devices/$normalizedDeviceId': {
        'role': 'owner',
        'nickname': 'Smart Switch',
        'active': true,
        'addedAt': ServerValue.timestamp,
        'transferredAt': ServerValue.timestamp,
      },
      'accessInvites/$code/status': DeviceInviteStatus.completed.firebaseValue,
      'accessInvites/$code/completedAt': ServerValue.timestamp,
    };

    for (final previousUid in previousAccess) {
      if (previousUid != newOwnerUid) {
        updates['users/$previousUid/devices/$normalizedDeviceId'] = null;
      }
    }

    await _database.ref().update(updates);
  }

}
