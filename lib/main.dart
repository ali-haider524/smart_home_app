import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_appearance.dart';
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
    if (e.code != 'duplicate-app') rethrow;
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
  final AppAppearanceController _appearanceController =
  AppAppearanceController();

  @override
  void initState() {
    super.initState();
    _languageController.start();
    _appearanceController.start();
  }

  @override
  void dispose() {
    _languageController.dispose();
    _appearanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appearanceController,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: _languageController,
          builder: (context, _) {
            return AppAppearanceScope(
              controller: _appearanceController,
              child: AppLanguageScope(
                controller: _languageController,
                child: MaterialApp(
                  title: 'Easy Home Control',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: _appearanceController.themeMode,
                  locale: _languageController.locale,
                  supportedLocales: const [Locale('en'), Locale('ur')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) {
                    return Directionality(
                      textDirection: _languageController.textDirection,
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                  home: const SplashScreen(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
