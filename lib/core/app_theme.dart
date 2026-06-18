import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFFF4F7FB);
  static const Color primary = Color(0xFF2F6DA5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1F2933);
  static const Color textLight = Color(0xFF6B7280);

  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: background,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: textDark),
    ),
  );
}