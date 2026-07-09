import 'package:flutter/material.dart';

/// Shared visual tokens for Easy Home Control.
///
/// The brand stays bright, clean and electric in light mode. In dark mode the
/// same tokens resolve to night-safe surfaces and text colours, so the app can
/// change appearance without touching Firebase, device, or firmware logic.
class AppTheme {
  static bool _darkMode = false;

  static bool get isDarkMode => _darkMode;

  /// Called only by [AppAppearanceController]. Keeping this visual state here
  /// allows existing presentation widgets to keep using the shared tokens.
  static void setDarkMode(bool value) {
    _darkMode = value;
  }

  // Brand colours stay consistent in both themes.
  static const Color primary = Color(0xFF2D5BFF);
  static const Color primaryDark = Color(0xFF173FAF);
  static const Color electric = Color(0xFF31B8FF);

  static const Color success = Color(0xFF249B63);
  static const Color warning = Color(0xFFD28A12);
  static const Color automation = Color(0xFF7259C9);

  // Adaptive semantic colours used by presentation widgets throughout lib/.
  static Color get darkText => _darkMode
      ? const Color(0xFFF4F7FF)
      : const Color(0xFF13213D);
  static Color get lightText => _darkMode
      ? const Color(0xFFAFBDD4)
      : const Color(0xFF74819A);

  static Color get background => _darkMode
      ? const Color(0xFF0B1220)
      : const Color(0xFFF6F8FC);
  static Color get card => _darkMode
      ? const Color(0xFF121D30)
      : const Color(0xFFFFFFFF);
  static Color get surfaceSoft => _darkMode
      ? const Color(0xFF1A2940)
      : const Color(0xFFF0F4FB);
  static Color get outline => _darkMode
      ? const Color(0xFF2A3A54)
      : const Color(0xFFE2E9F3);
  static Color get electricSoft => _darkMode
      ? const Color(0xFF102D51)
      : const Color(0xFFEAF2FF);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0B1220)
        : const Color(0xFFF6F8FC);
    final card = isDark ? const Color(0xFF121D30) : Colors.white;
    final darkText = isDark
        ? const Color(0xFFF4F7FF)
        : const Color(0xFF13213D);
    final lightText = isDark
        ? const Color(0xFFAFBDD4)
        : const Color(0xFF74819A);
    final outline = isDark
        ? const Color(0xFF2A3A54)
        : const Color(0xFFE2E9F3);
    final electricSoft = isDark
        ? const Color(0xFF102D51)
        : const Color(0xFFEAF2FF);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        secondary: electric,
        onPrimary: Colors.white,
        surface: card,
        onSurface: darkText,
        outline: outline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: darkText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shadowColor: primary.withValues(alpha: isDark ? 0.34 : 0.24),
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFFBFD1FF) : primaryDark,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: outline),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFF91B6FF) : primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? const Color(0xFF2E63FF) : primaryDark,
        foregroundColor: Colors.white,
        elevation: 8,
        focusElevation: 10,
        hoverElevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: lightText, fontSize: 14),
        labelStyle: TextStyle(color: lightText),
        prefixIconColor: darkText,
        suffixIconColor: lightText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1D2C45) : darkText,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: isDark ? 0.28 : 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: lightText, fontWeight: FontWeight.w700),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: TextStyle(color: lightText, height: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),
    );
  }
}
