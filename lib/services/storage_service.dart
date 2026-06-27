import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'username_generator.dart';

/// Hardened persistence. **Everything** that survives restarts is stored in
/// hardware-backed secure storage (iOS Keychain / Android Keystore via
/// EncryptedSharedPreferences) — there is no plaintext on disk.
///
/// Security properties:
///  * iOS items use `first_unlock_this_device`: encrypted at rest, available
///    only after first unlock, **never** synced to iCloud or migrated to a new
///    device. The Beau identity is bound to this physical device (BBM-style).
///  * Android items use EncryptedSharedPreferences (AES via Jetpack Security),
///    keys held in the Keystore (StrongBox/TEE where available).
///  * The device PIN is generated with a cryptographically secure RNG.
/// Values are cached in memory after a single decrypt at startup so the rest
/// of the app keeps a fast, synchronous API while at-rest data stays encrypted.
class StorageService {
  static const _kPin = 'beau.pin';
  static const _kPostCount = 'beau.postCount';
  static const _kLastPostIso = 'beau.lastPostIso';
  static const _kOnboarded = 'beau.onboarded';
  static const _kTheme = 'beau.themeMode';
  static const _kMyStory = 'beau.myStory';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  String _pin = '';
  int _postCount = 0;
  String? _lastPostIso;
  bool _onboarded = false;
  String _themeMode = 'system';
  String? _myStoryJson;

  Future<void> init() async {
    _pin = await _readOrCreatePin();
    _postCount = int.tryParse(await _read(_kPostCount) ?? '') ?? 0;
    _lastPostIso = await _read(_kLastPostIso);
    _onboarded = (await _read(_kOnboarded)) == 'true';
    _themeMode = await _read(_kTheme) ?? 'system';
    _myStoryJson = await _read(_kMyStory);
  }

  Future<String?> _read(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String? value) async {
    try {
      if (value == null) {
        await _secure.delete(key: key);
      } else {
        await _secure.write(key: key, value: value);
      }
    } catch (_) {
      // Best-effort; in-memory cache still serves this session.
    }
  }

  // ---- device identity (BBM-style PIN) ---------------------------------

  Future<String> _readOrCreatePin() async {
    final existing = await _read(_kPin);
    if (existing != null && existing.isNotEmpty) return existing;
    final pin = _generatePin();
    await _write(_kPin, pin);
    return pin;
  }

  /// Charset for Beau PINs: Crockford base32 — digits + letters, with the
  /// ambiguous I, L, O, U removed so PINs are easy to read aloud and type.
  static const _pinAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// 8-char alphanumeric PIN, e.g. "K7Q2M9XB" — ~40 bits from a CSPRNG. Across
  /// 32^8 (~1.1e12) possibilities collisions are practically impossible; Phase
  /// 2 (Firebase) additionally enforces global uniqueness on write.
  String _generatePin() {
    final r = Random.secure();
    while (true) {
      final sb = StringBuffer();
      for (var i = 0; i < 8; i++) {
        sb.write(_pinAlphabet[r.nextInt(_pinAlphabet.length)]);
      }
      final pin = sb.toString();
      // Guarantee it's alphanumeric in practice: at least one letter + digit.
      if (pin.contains(RegExp('[0-9]')) && pin.contains(RegExp('[A-Z]'))) {
        return pin;
      }
    }
  }

  /// Normalise user-entered PIN input: uppercase, strip spaces/dashes.
  static String normalizePin(String raw) =>
      raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  /// A plausible PIN is 6–12 alphanumerics (lenient so typos surface clearly).
  static bool isValidPin(String raw) {
    final p = normalizePin(raw);
    return p.length >= 6 && p.length <= 12;
  }

  String get pin => _pin;

  /// Deterministic seed from the PIN (handle + avatar derive from this).
  int get identitySeed => UsernameGenerator.seedFromPin(_pin);

  // ---- app state (all encrypted at rest) -------------------------------

  int get postCount => _postCount;
  bool get onboarded => _onboarded;
  String get themeMode => _themeMode;

  DateTime? get lastPostAt =>
      _lastPostIso == null ? null : DateTime.tryParse(_lastPostIso!);

  Map<String, dynamic>? get myStory {
    if (_myStoryJson == null) return null;
    try {
      return jsonDecode(_myStoryJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setOnboarded(bool v) async {
    _onboarded = v;
    await _write(_kOnboarded, v ? 'true' : 'false');
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _write(_kTheme, mode);
  }

  Future<void> recordPost(Map<String, dynamic> storyJson) async {
    _postCount += 1;
    _lastPostIso = DateTime.now().toIso8601String();
    _myStoryJson = jsonEncode(storyJson);
    await _write(_kPostCount, '$_postCount');
    await _write(_kLastPostIso, _lastPostIso);
    await _write(_kMyStory, _myStoryJson);
  }

  Future<void> clearMyStory() async {
    _myStoryJson = null;
    await _write(_kMyStory, null);
  }
}
