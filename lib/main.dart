import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'features/auth/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }

  runApp(const SmartSwitchApp());
}

class SmartSwitchApp extends StatefulWidget {
  const SmartSwitchApp({super.key});

  @override
  State<SmartSwitchApp> createState() => _SmartSwitchAppState();
}

class _SmartSwitchAppState extends State<SmartSwitchApp> {
  final AppLanguageController _languageController = AppLanguageController();

  @override
  void initState() {
    super.initState();
    _languageController.start();
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageController,
      builder: (context, _) {
        return AppLanguageScope(
          controller: _languageController,
          child: MaterialApp(
            title: 'Easy Home Control',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: _languageController.locale,
            supportedLocales: const [Locale('en'), Locale('ur')],
            builder: (context, child) {
              return Directionality(
                textDirection: _languageController.textDirection,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
