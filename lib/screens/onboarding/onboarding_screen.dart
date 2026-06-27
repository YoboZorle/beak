import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
// PIN shown below is the device-bound identity (see StorageService).
import '../../widgets/anime_avatar.dart';
import '../home/home_shell.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _points = [
    ('🔒', 'Anonymous by design',
        'No phone number. No sign-up. No real photos. Just a generated handle tied to this device — like BBM.'),
    ('📡', 'Shake to discover',
        'Shake your phone to scan the beacon. See anonymous people 0–30 km around you, ranked by distance.'),
    ('🕒', 'Post to unlock',
        'Drop one 5-min story (demo) — a text card, a photo, or a 15s voice note. It puts you on the map and reveals everyone around you.'),
    ('🏆', 'Level up',
        'Every story you post fills your rank — Rookie to Mythic. Be active, climb the ladder.'),
  ];

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().me;
    final pin = context.read<StorageService>().pin;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Welcome to Beau',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              if (me != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      AnimeAvatar(seed: me.avatarSeed, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Beau PIN · this device',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(pin,
                                style: const TextStyle(
                                    color: AppColors.accentSoft,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2)),
                            Text(me.username,
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _points.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 18),
                  itemBuilder: (_, i) {
                    final p = _points[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.$1, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.$2,
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(p.$3,
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    await context.read<StorageService>().setOnboarded(true);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => const HomeShell()));
                  },
                  child: const Text('Enter the beacon',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
