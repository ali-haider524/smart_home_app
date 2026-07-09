import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// Uses Realtime Database's server-time offset so time-based UI, such as a
/// device heartbeat, remains consistent across different customer phones.
///
/// This is read-only. It does not change any device, timer, schedule, or
/// Firebase command path.
class ServerClock {
  ServerClock._();

  static final ServerClock instance = ServerClock._();

  StreamSubscription<DatabaseEvent>? _offsetSubscription;
  bool _started = false;
  int _offsetMilliseconds = 0;

  int get nowMilliseconds =>
      DateTime.now().millisecondsSinceEpoch + _offsetMilliseconds;

  void start(FirebaseDatabase database) {
    if (_started) return;
    _started = true;

    _offsetSubscription = database.ref('.info/serverTimeOffset').onValue.listen(
          (event) {
        final value = event.snapshot.value;

        if (value is num) {
          _offsetMilliseconds = value.toInt();
          return;
        }

        _offsetMilliseconds =
            int.tryParse(value?.toString() ?? '') ?? _offsetMilliseconds;
      },
      onError: (_) {
        // Keep the local clock as a safe temporary fallback. The listener
        // reconnects automatically when Firebase is available again.
      },
    );
  }
}
