import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_controller.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class BeauApp extends StatefulWidget {
  const BeauApp({super.key});

  @override
  State<BeauApp> createState() => _BeauAppState();
}

class _BeauAppState extends State<BeauApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Rebuild when the OS light/dark setting flips (matters in system mode).
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeController>().mode;
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platform,
    };

    // Resolve neutrals for this build BEFORE the theme/UI reads them.
    AppColors.brightness = brightness;

    return MaterialApp(
      title: 'Beau',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themed(brightness),
      home: const SplashScreen(),
    );
  }
}
