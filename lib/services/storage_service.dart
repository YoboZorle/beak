import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for everything that must survive restarts.
///
/// Two tiers:
///  * **Secure** (Keychain / Keystore via flutter_secure_storage): the durable
///    device identity — the Beau PIN. This binds the identity to the device
///    like a BBM PIN: whoever installs Beau on this device becomes this user.
///  * **Prefs** (SharedPreferences): app state — level/post count, the last
///    post timestamp (24h rule), onboarding flag, and the cached live story.
class StorageService {
  static const _kPin = 'beau.pin'; // secure
  static const _kPostCount = 'beau.postCount';
  static const _kLastPostIso = 'beau.lastPostIso';
  static const _kOnboarded = 'beau.onboarded';
  static const _kMyStory = 'beau.myStory';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  late final SharedPreferences _prefs;

  String _pin = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadOrCreatePin();
  }

  // ---- device identity (BBM-style PIN) ---------------------------------

  Future<void> _loadOrCreatePin() async {
    String? existing;
    try {
      existing = await _secure.read(key: _kPin);
    } catch (_) {
      existing = null; // secure storage unavailable -> fall back below
    }
    if (existing == null || existing.isEmpty) {
      existing = _generatePin();
      try {
        await _secure.write(key: _kPin, value: existing);
      } catch (_) {
        // If the keystore is unavailable, mirror to prefs so the identity is
        // still stable for this install.
        await _prefs.setString(_kPin, existing);
      }
    }
    _pin = existing;
  }

  /// 8 uppercase hex chars, e.g. "2F9C4A7B" — the public, device-bound id.
  String _generatePin() {
    final r = Random.secure();
    final b = List<int>.generate(4, (_) => r.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  /// The Beau PIN — the device-bound identity. Stable across restarts.
  String get pin => _pin;

  /// Numeric seed derived from the PIN, used to deterministically pick the
  /// handle + avatar so the identity is reproducible from the PIN alone.
  int get identitySeed {
    var h = 0;
    for (final c in _pin.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h;
  }

  // ---- app state -------------------------------------------------------

  int get postCount => _prefs.getInt(_kPostCount) ?? 0;
  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;

  DateTime? get lastPostAt {
    final iso = _prefs.getString(_kLastPostIso);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Map<String, dynamic>? get myStory {
    final raw = _prefs.getString(_kMyStory);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> setOnboarded(bool v) => _prefs.setBool(_kOnboarded, v);

  Future<void> recordPost(Map<String, dynamic> storyJson) async {
    await _prefs.setInt(_kPostCount, postCount + 1);
    await _prefs.setString(_kLastPostIso, DateTime.now().toIso8601String());
    await _prefs.setString(_kMyStory, jsonEncode(storyJson));
  }

  Future<void> clearMyStory() => _prefs.remove(_kMyStory);
}
