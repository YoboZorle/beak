import 'package:flutter/material.dart';

/// Beau palette — pulled from the Beacon reference: near-black field,
/// faint radar lines, a violet accent, and saturated "signal" blips.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF050507);
  static const Color surface = Color(0xFF0E0E12);
  static const Color surfaceHigh = Color(0xFF16161C);
  static const Color stroke = Color(0xFF222230);

  static const Color textPrimary = Color(0xFFF4F4F6);
  static const Color textSecondary = Color(0xFF9A9AA8);
  static const Color textMuted = Color(0xFF5E5E6E);

  /// "Friends Near You" violet from the reference.
  static const Color accent = Color(0xFF6C6CFF);
  static const Color accentSoft = Color(0xFF8E8EFF);

  // Radar signal blips
  static const List<Color> blips = [
    Color(0xFF4F8BFF), // blue
    Color(0xFFFF8A3D), // orange
    Color(0xFFFF5470), // red
    Color(0xFF49D17A), // green
    Color(0xFFC56CFF), // violet
    Color(0xFFFFD166), // amber
  ];

  /// Deterministic palette for anonymous anime avatars.
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF6C6CFF), Color(0xFF3A2BD8)],
    [Color(0xFFFF5470), Color(0xFFB8003A)],
    [Color(0xFF49D17A), Color(0xFF0E8F4F)],
    [Color(0xFFFF8A3D), Color(0xFFCC4E00)],
    [Color(0xFF4F8BFF), Color(0xFF1B47B0)],
    [Color(0xFFC56CFF), Color(0xFF7A1FB0)],
    [Color(0xFFFFD166), Color(0xFFCF9A00)],
    [Color(0xFF2EE6D6), Color(0xFF0A8E84)],
  ];
}
