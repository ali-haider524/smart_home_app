import 'dart:async';

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

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
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