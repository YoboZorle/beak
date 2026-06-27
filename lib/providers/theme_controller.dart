import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Holds the user's theme choice (system / light / dark), restored from and
/// persisted to secure storage. The app root watches this and rebuilds.
class ThemeController extends ChangeNotifier {
  ThemeController(this._storage) {
    _mode = _parse(_storage.themeMode);
  }

  final StorageService _storage;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    _storage.setThemeMode(_name(m));
    notifyListeners();
  }

  static ThemeMode _parse(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _name(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
