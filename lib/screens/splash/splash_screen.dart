import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _boot();
  }

  Future<void> _boot() async {
    final session = context.read<SessionProvider>();
    final storage = context.read<StorageService>();
    await session.bootstrap();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final next = storage.onboarded
        ? const HomeShell()
        : const OnboardingScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: next),
      ),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  painter: _BeaconPulsePainter(_pulse.value),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Beau',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1)),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Shake your beacon. Meet anonymous anime fans near you. No phone number, no profile, no strings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeaconPulsePainter extends CustomPainter {
  _BeaconPulsePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = maxR * p;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent.withOpacity((1 - p) * 0.7);
      canvas.drawCircle(center, r, paint);
    }
    final core = Paint()
      ..shader = const RadialGradient(
        colors: [AppColors.accentSoft, AppColors.accent],
      ).createShader(Rect.fromCircle(center: center, radius: 18));
    canvas.drawCircle(center, 16, core);
  }

  @override
  bool shouldRepaint(covariant _BeaconPulsePainter old) => old.t != t;
}
