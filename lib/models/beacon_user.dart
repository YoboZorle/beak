import 'level.dart';

/// An anonymous person discoverable on the beacon.
///
/// No phone, no real name, no photo — just a generated handle, a
/// deterministic avatar seed, a level, and a distance from you.
class BeaconUser {
  final String id;
  final String username; // e.g. "bleach-778"
  final int avatarSeed; // picks gradient + face deterministically
  final Level level;

  /// Distance from the current device, in metres.
  final double distanceMeters;

  /// Whether this user currently has a live (<24h) story on the beacon.
  final bool hasStory;

  /// Bearing 0..2π for radar placement (purely visual).
  final double bearing;

  const BeaconUser({
    required this.id,
    required this.username,
    required this.avatarSeed,
    required this.level,
    required this.distanceMeters,
    required this.hasStory,
    required this.bearing,
  });

  double get distanceKm => distanceMeters / 1000.0;

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m away';
    return '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)} km away';
  }

  BeaconUser copyWith({double? distanceMeters, bool? hasStory, double? bearing}) {
    return BeaconUser(
      id: id,
      username: username,
      avatarSeed: avatarSeed,
      level: level,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      hasStory: hasStory ?? this.hasStory,
      bearing: bearing ?? this.bearing,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'avatarSeed': avatarSeed,
        'level': level.toJson(),
        'distanceMeters': distanceMeters,
        'hasStory': hasStory,
        'bearing': bearing,
      };

  factory BeaconUser.fromJson(Map<String, dynamic> j) => BeaconUser(
        id: j['id'] as String,
        username: j['username'] as String,
        avatarSeed: j['avatarSeed'] as int? ?? 0,
        level: Level.fromJson(
            (j['level'] as Map?)?.cast<String, dynamic>() ?? const {}),
        distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0,
        hasStory: j['hasStory'] as bool? ?? false,
        bearing: (j['bearing'] as num?)?.toDouble() ?? 0,
      );
}
