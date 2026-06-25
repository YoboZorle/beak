import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  String? _myStoryJson;

  Future<void> init() async {
    _pin = await _readOrCreatePin();
    _postCount = int.tryParse(await _read(_kPostCount) ?? '') ?? 0;
    _lastPostIso = await _read(_kLastPostIso);
    _onboarded = (await _read(_kOnboarded)) == 'true';
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

  /// 8 uppercase hex chars (e.g. "2F9C4A7B"), from a CSPRNG.
  String _generatePin() {
    final r = Random.secure();
    final b = List<int>.generate(4, (_) => r.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  String get pin => _pin;

  /// Deterministic seed from the PIN (handle + avatar derive from this).
  int get identitySeed {
    var h = 0;
    for (final c in _pin.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h;
  }

  // ---- app state (all encrypted at rest) -------------------------------

  int get postCount => _postCount;
  bool get onboarded => _onboarded;

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
