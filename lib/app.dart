import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

class BeauApp extends StatelessWidget {
  const BeauApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beau',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
