import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const SmartSwitchApp());
}

class SmartSwitchApp extends StatelessWidget {
  const SmartSwitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Switch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}