import 'dart:math';

/// Generates BBM-style anonymous handles like `bleach-778`, `bluesky-090`,
/// `vanguard-221`. Word list leans anime / vibe so it fits Beau.
///
/// Supports deterministic generation from a seed so a device's identity is
/// stable: the same device PIN always yields the same handle + avatar — i.e.
/// whoever holds the device *is* that identity (like a BBM PIN).
class UsernameGenerator {
  UsernameGenerator._();

  static const List<String> _words = [
    'bleach', 'bluesky', 'vanguard', 'finegrain', 'shadow', 'sakura',
    'ronin', 'nimbus', 'akira', 'phantom', 'mecha', 'kitsune', 'ember',
    'glacier', 'onyx', 'zenith', 'comet', 'raiden', 'lotus', 'falcon',
    'tsunami', 'mirage', 'cipher', 'nova', 'drift', 'echo', 'kage',
    'senpai', 'oracle', 'voltage', 'crimson', 'aurora', 'specter',
    'wraith', 'titan', 'cobalt', 'frost', 'blaze', 'lunar', 'solar',
  ];

  static final Random _rng = Random();

  static String generate() => generateFrom(_rng.nextInt(1 << 31));
  static int avatarSeed() => _rng.nextInt(1 << 20);

  /// Deterministic handle from [seed].
  static String generateFrom(int seed) {
    final r = Random(seed);
    final word = _words[r.nextInt(_words.length)];
    final number = r.nextInt(1000).toString().padLeft(3, '0');
    return '$word-$number';
  }

  /// Deterministic avatar seed from [seed].
  static int avatarSeedFrom(int seed) => Random(seed ^ 0x5DEECE66).nextInt(1 << 20);
}
