/// Access roles are deliberately small. The Firebase Rules remain the source of
/// truth; this model is used only for app presentation and safe navigation.
enum DeviceAccessRole {
  owner,
  member,
  unknown;

  bool get isOwner => this == DeviceAccessRole.owner;
  bool get canControl => this == DeviceAccessRole.owner || this == DeviceAccessRole.member;

  String get firebaseValue {
    switch (this) {
      case DeviceAccessRole.owner:
        return 'owner';
      case DeviceAccessRole.member:
        return 'member';
      case DeviceAccessRole.unknown:
        return 'unknown';
    }
  }

  static DeviceAccessRole fromValue(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'owner':
        return DeviceAccessRole.owner;
      case 'member':
        return DeviceAccessRole.member;
      default:
        return DeviceAccessRole.unknown;
    }
  }
}

enum DeviceInviteType {
  share,
  transfer;

  String get firebaseValue => this == DeviceInviteType.share ? 'share' : 'transfer';

  static DeviceInviteType? fromValue(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'share':
        return DeviceInviteType.share;
      case 'transfer':
        return DeviceInviteType.transfer;
      default:
        return null;
    }
  }
}

enum DeviceInviteStatus {
  pending,
  accepted,
  completed,
  cancelled,
  unknown;

  String get firebaseValue {
    switch (this) {
      case DeviceInviteStatus.pending:
        return 'pending';
      case DeviceInviteStatus.accepted:
        return 'accepted';
      case DeviceInviteStatus.completed:
        return 'completed';
      case DeviceInviteStatus.cancelled:
        return 'cancelled';
      case DeviceInviteStatus.unknown:
        return 'unknown';
    }
  }

  static DeviceInviteStatus fromValue(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'pending':
        return DeviceInviteStatus.pending;
      case 'accepted':
        return DeviceInviteStatus.accepted;
      case 'completed':
        return DeviceInviteStatus.completed;
      case 'cancelled':
        return DeviceInviteStatus.cancelled;
      default:
        return DeviceInviteStatus.unknown;
    }
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class DeviceAccessInfo {
  final String deviceId;
  final DeviceAccessRole role;
  final String nickname;
  final bool active;

  const DeviceAccessInfo({
    required this.deviceId,
    required this.role,
    required this.nickname,
    required this.active,
  });

  bool get isOwner => role.isOwner;
  bool get isMember => role == DeviceAccessRole.member;

  factory DeviceAccessInfo.empty(String deviceId) {
    return DeviceAccessInfo(
      deviceId: deviceId,
      role: DeviceAccessRole.unknown,
      nickname: 'Smart Switch',
      active: false,
    );
  }

  factory DeviceAccessInfo.fromMap(
      String deviceId,
      Map<dynamic, dynamic> map,
      ) {
    final nickname = map['nickname']?.toString().trim();
    return DeviceAccessInfo(
      deviceId: deviceId,
      role: DeviceAccessRole.fromValue(map['role']),
      nickname: nickname == null || nickname.isEmpty ? 'Smart Switch' : nickname,
      active: map['active'] != false,
    );
  }
}

class DeviceAccessMember {
  final String uid;
  final DeviceAccessRole role;
  final String displayLabel;
  final int addedAt;

  const DeviceAccessMember({
    required this.uid,
    required this.role,
    required this.displayLabel,
    required this.addedAt,
  });

  bool get isOwner => role.isOwner;

  String get shortUid {
    if (uid.length <= 8) return uid;
    return '${uid.substring(0, 4)}…${uid.substring(uid.length - 3)}';
  }

  factory DeviceAccessMember.fromMap(
      String uid,
      Map<dynamic, dynamic> map,
      ) {
    final label = map['displayLabel']?.toString().trim();
    return DeviceAccessMember(
      uid: uid,
      role: DeviceAccessRole.fromValue(map['role']),
      displayLabel: label == null || label.isEmpty ? 'Shared user' : label,
      addedAt: _readInt(map['addedAt']),
    );
  }
}

class DeviceAccessInvite {
  final String code;
  final String deviceId;
  final DeviceInviteType type;
  final DeviceInviteStatus status;
  final String createdBy;
  final int expiresAt;
  final String acceptedBy;
  final String recipientLabel;

  const DeviceAccessInvite({
    required this.code,
    required this.deviceId,
    required this.type,
    required this.status,
    required this.createdBy,
    required this.expiresAt,
    required this.acceptedBy,
    required this.recipientLabel,
  });

  bool get isExpired => expiresAt > 0 && DateTime.now().millisecondsSinceEpoch >= expiresAt;
  bool get isPending => status == DeviceInviteStatus.pending && !isExpired;
  bool get isAccepted => status == DeviceInviteStatus.accepted;

  String get displayCode {
    final buffer = StringBuffer();
    for (var index = 0; index < code.length; index++) {
      if (index > 0 && index % 4 == 0) buffer.write('-');
      buffer.write(code[index]);
    }
    return buffer.toString();
  }

  factory DeviceAccessInvite.fromMap(
      String code,
      Map<dynamic, dynamic> map,
      ) {
    final type = DeviceInviteType.fromValue(map['type']);
    return DeviceAccessInvite(
      code: code,
      deviceId: map['deviceId']?.toString().trim().toUpperCase() ?? '',
      type: type ?? DeviceInviteType.share,
      status: DeviceInviteStatus.fromValue(map['status']),
      createdBy: map['createdBy']?.toString() ?? '',
      expiresAt: _readInt(map['expiresAt']),
      acceptedBy: map['acceptedBy']?.toString() ?? '',
      recipientLabel: map['recipientLabel']?.toString().trim() ?? '',
    );
  }
}

enum SharedDeviceJoinOutcome {
  added,
  restored,
  alreadyAdded,
  transferWaiting,
}

class SharedDeviceJoinResult {
  final SharedDeviceJoinOutcome outcome;
  final String deviceId;
  final String nickname;

  const SharedDeviceJoinResult({
    required this.outcome,
    required this.deviceId,
    required this.nickname,
  });

  bool get addsToDashboard => outcome != SharedDeviceJoinOutcome.transferWaiting;
}
