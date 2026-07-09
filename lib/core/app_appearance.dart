import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

enum AppAppearance { light, dark }

extension AppAppearanceValue on AppAppearance {
  String get databaseValue => switch (this) {
    AppAppearance.light => 'light',
    AppAppearance.dark => 'dark',
  };

  static AppAppearance fromDatabaseValue(Object? value) {
    return value?.toString().trim().toLowerCase() == 'dark'
        ? AppAppearance.dark
        : AppAppearance.light;
  }
}

/// Stores only a personal visual preference under the signed-in user's own
/// preferences node. It does not read or modify a switch, command, timer,
/// schedule, ownership record, Wi-Fi setup, or ESP firmware path.
class AppAppearanceController extends ChangeNotifier {
  AppAppearance _appearance = AppAppearance.light;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DatabaseEvent>? _preferenceSubscription;
  bool _started = false;

  AppAppearance get appearance => _appearance;
  bool get isDark => _appearance == AppAppearance.dark;
  ThemeMode get themeMode => isDark ? ThemeMode.dark : ThemeMode.light;

  void start() {
    if (_started) return;
    _started = true;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChanged,
      onError: (_) {},
    );
  }

  void _handleAuthChanged(User? user) {
    _preferenceSubscription?.cancel();
    _preferenceSubscription = null;

    if (user == null) {
      _setAppearance(AppAppearance.light);
      return;
    }

    final ref = FirebaseDatabase.instance
        .ref('users/${user.uid}/preferences/appAppearance');

    _preferenceSubscription = ref.onValue.listen(
          (event) => _setAppearance(
        AppAppearanceValue.fromDatabaseValue(event.snapshot.value),
      ),
      onError: (_) {
        // Keep the locally selected appearance during a temporary read error.
      },
    );
  }

  Future<bool> setAppearance(AppAppearance appearance) async {
    _setAppearance(appearance);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/preferences/appAppearance')
          .set(appearance.databaseValue);
      return true;
    } catch (_) {
      // The visual preference is already applied for this session. The caller
      // can show a non-blocking message that persistence will retry later.
      return false;
    }
  }

  void _setAppearance(AppAppearance appearance) {
    final changed = _appearance != appearance;
    _appearance = appearance;
    AppTheme.setDarkMode(appearance == AppAppearance.dark);
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _preferenceSubscription?.cancel();
    super.dispose();
  }
}

class AppAppearanceScope extends InheritedNotifier<AppAppearanceController> {
  const AppAppearanceScope({
    super.key,
    required AppAppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppAppearanceController controllerOf(BuildContext context) {
    final scope =
    context.dependOnInheritedWidgetOfExactType<AppAppearanceScope>();
    assert(scope != null, 'AppAppearanceScope is missing above this context.');
    return scope!.notifier!;
  }
}

extension AppAppearanceContext on BuildContext {
  AppAppearanceController get appearanceController =>
      AppAppearanceScope.controllerOf(this);
}
