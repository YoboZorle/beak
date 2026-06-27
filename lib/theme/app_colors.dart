import 'package:flutter/material.dart';

/// Beau palette. Neutrals are **theme-aware** (resolve from [brightness], set by
/// the app root from the active ThemeMode); the violet brand accent and the
/// saturated signal/avatar colors stay constant across light and dark.
class AppColors {
  AppColors._();

  /// Active brightness — assigned once per build by the app root.
  static Brightness brightness = Brightness.dark;
  static bool get _d => brightness == Brightness.dark;

  // ---- dark neutrals ----
  static const Color _bgD = Color(0xFF050507);
  static const Color _surfD = Color(0xFF0E0E12);
  static const Color _surfHiD = Color(0xFF16161C);
  static const Color _strokeD = Color(0xFF222230);
  static const Color _tpD = Color(0xFFF4F4F6);
  static const Color _tsD = Color(0xFF9A9AA8);
  static const Color _tmD = Color(0xFF5E5E6E);

  // ---- light neutrals ----
  static const Color _bgL = Color(0xFFF5F6FB);
  static const Color _surfL = Color(0xFFFFFFFF);
  static const Color _surfHiL = Color(0xFFECEDF4);
  static const Color _strokeL = Color(0xFFDDDEEA);
  static const Color _tpL = Color(0xFF15151C);
  static const Color _tsL = Color(0xFF565663);
  static const Color _tmL = Color(0xFF9A9AA8);

  static Color get background => _d ? _bgD : _bgL;
  static Color get surface => _d ? _surfD : _surfL;
  static Color get surfaceHigh => _d ? _surfHiD : _surfHiL;
  static Color get stroke => _d ? _strokeD : _strokeL;
  static Color get textPrimary => _d ? _tpD : _tpL;
  static Color get textSecondary => _d ? _tsD : _tsL;
  static Color get textMuted => _d ? _tmD : _tmL;

  // ---- brand + signals (constant across themes) ----
  static const Color accent = Color(0xFF6C6CFF);
  static const Color accentSoft = Color(0xFF8E8EFF);

  static const List<Color> blips = [
    Color(0xFF4F8BFF),
    Color(0xFFFF8A3D),
    Color(0xFFFF5470),
    Color(0xFF49D17A),
    Color(0xFFC56CFF),
    Color(0xFFFFD166),
  ];

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
