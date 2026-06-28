import 'dart:async';

/// A local UI refresh only. It does not make Firebase requests.
/// Firebase device data still arrives through Realtime Database streams.
class AppTicker {
  AppTicker._internal();

  static final AppTicker instance = AppTicker._internal();

  final StreamController<DateTime> _controller =
  StreamController<DateTime>.broadcast();

  Timer? _timer;

  Stream<DateTime> get stream {
    _startIfNeeded();
    return _controller.stream;
  }

  void _startIfNeeded() {
    if (_timer != null) return;

    _controller.add(DateTime.now());

    // Only refreshes labels such as "12 sec ago". It does not read Firebase.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.isClosed) {
        _controller.add(DateTime.now());
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;

    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
