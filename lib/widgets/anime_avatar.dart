import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Anonymous anime-style avatar.
///
/// No photos, ever. Each user gets a deterministic gradient background plus a
/// stylised face glyph derived from their seed — unique-feeling, zero assets.
/// Drop real anime PNGs into assets/avatars/ later and swap the child here.
class AnimeAvatar extends StatelessWidget {
  const AnimeAvatar({
    super.key,
    required this.seed,
    this.size = 48,
    this.hasStory = false,
    this.ringColor,
  });

  final int seed;
  final double size;
  final bool hasStory;
  final Color? ringColor;

  // A small set of anime-ish face emoji; picked deterministically by seed.
  static const List<String> _faces = [
    '🦊', '🐱', '👾', '🥷', '🐉', '🌸', '⚡', '🌙',
    '🔥', '❄️', '🦋', '🍥', '👁️', '🌀', '✨', '🗡️',
  ];

  @override
  Widget build(BuildContext context) {
    final gradient =
        AppColors.avatarGradients[seed % AppColors.avatarGradients.length];
    final face = _faces[(seed ~/ 7) % _faces.length];

    final ring = hasStory ? (ringColor ?? AppColors.accent) : Colors.transparent;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(hasStory ? size * 0.05 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: hasStory ? 2 : 0),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.35),
              blurRadius: size * 0.25,
              spreadRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          face,
          style: TextStyle(fontSize: size * 0.46),
        ),
      ),
    );
  }
}
