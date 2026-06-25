import 'beacon_user.dart';
import 'level.dart';

/// The kind of post on the beacon.
enum StoryType { textCard, imageText, voiceNote }

extension StoryTypeX on StoryType {
  String get id => name;
  static StoryType fromId(String? id) {
    for (final t in StoryType.values) {
      if (t.name == id) return t;
    }
    return StoryType.textCard;
  }
}

/// A 24-hour post shown on the beacon.
///
/// One of three kinds:
///  * [StoryType.textCard]  — a caption on a coloured gradient card.
///  * [StoryType.imageText] — a local image ([imagePath]) + caption.
///  * [StoryType.voiceNote] — a recorded clip ([audioPath], <=15s) + caption.
///
/// In Phase 2 [imageUrl]/[audioUrl] are populated from Storage; the local
/// paths are used while running fully on-device.
class Story {
  final String id;
  final String authorId;
  final String authorUsername;
  final int authorAvatarSeed;
  final Level authorLevel;

  final StoryType type;

  /// Background gradient for text cards (and image fallback).
  final int gradientIndex;

  /// Local file path for an image post (Phase 1) / remote url (Phase 2).
  final String? imagePath;
  final String? imageUrl;

  /// Local file path for a voice note (Phase 1) / remote url (Phase 2).
  final String? audioPath;
  final String? audioUrl;
  final int audioDurationMs;

  final String caption;
  final DateTime createdAt;

  /// Author distance from the current device (metres), for the feed/radar.
  final double distanceMeters;

  const Story({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.authorAvatarSeed,
    required this.authorLevel,
    required this.type,
    required this.gradientIndex,
    required this.caption,
    required this.createdAt,
    required this.distanceMeters,
    this.imagePath,
    this.imageUrl,
    this.audioPath,
    this.audioUrl,
    this.audioDurationMs = 0,
  });

  static const Duration lifetime = Duration(hours: 24);

  DateTime get expiresAt => createdAt.add(lifetime);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get remaining {
    final r = expiresAt.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  String? get effectiveImage => imageUrl ?? imagePath;
  String? get effectiveAudio => audioUrl ?? audioPath;

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  String get audioDurationLabel {
    final s = (audioDurationMs / 1000).round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  /// The author summarised as a BeaconUser (for avatars / headers / profile).
  BeaconUser get author => BeaconUser(
        id: authorId,
        username: authorUsername,
        avatarSeed: authorAvatarSeed,
        level: authorLevel,
        distanceMeters: distanceMeters,
        hasStory: true,
        bearing: 0,
      );

  Story copyWith({double? distanceMeters}) => Story(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        authorAvatarSeed: authorAvatarSeed,
        authorLevel: authorLevel,
        type: type,
        gradientIndex: gradientIndex,
        caption: caption,
        createdAt: createdAt,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        imagePath: imagePath,
        imageUrl: imageUrl,
        audioPath: audioPath,
        audioUrl: audioUrl,
        audioDurationMs: audioDurationMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorUsername': authorUsername,
        'authorAvatarSeed': authorAvatarSeed,
        'authorLevel': authorLevel.toJson(),
        'type': type.id,
        'gradientIndex': gradientIndex,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
        'audioPath': audioPath,
        'audioUrl': audioUrl,
        'audioDurationMs': audioDurationMs,
        'caption': caption,
        'createdAt': createdAt.toIso8601String(),
        'distanceMeters': distanceMeters,
      };

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        id: j['id'] as String,
        authorId: j['authorId'] as String,
        authorUsername: j['authorUsername'] as String,
        authorAvatarSeed: j['authorAvatarSeed'] as int? ?? 0,
        authorLevel: Level.fromJson(
            (j['authorLevel'] as Map?)?.cast<String, dynamic>() ?? const {}),
        type: StoryTypeX.fromId(j['type'] as String?),
        gradientIndex: j['gradientIndex'] as int? ?? 0,
        imagePath: j['imagePath'] as String?,
        imageUrl: j['imageUrl'] as String?,
        audioPath: j['audioPath'] as String?,
        audioUrl: j['audioUrl'] as String?,
        audioDurationMs: j['audioDurationMs'] as int? ?? 0,
        caption: j['caption'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0,
      );
}
