/// Progress / level system.
///
/// Every story you post adds progress. When progress fills, you rank up.
/// Ten ranks, from Rookie up to Mythic. Rookie clears at 3 posts; reaching
/// Mythic takes 365 lifetime posts.
class Level {
  /// 0-based stage index.
  final int stage;

  /// Progress within the current stage, 0.0 - 1.0.
  final double progress;

  const Level({required this.stage, required this.progress});

  static const List<String> stageNames = [
    'Rookie',
    'Amateur',
    'Rising',
    'Intermediate',
    'Skilled',
    'Veteran',
    'Elite',
    'Champion',
    'Legend',
    'Mythic',
  ];

  /// Posts required to clear each stage (incremental). The last value is only a
  /// display denominator for the max rank.
  /// Cumulative to reach Mythic = 3+5+8+14+25+35+60+90+125 = 365.
  static const List<int> postsPerStage = [3, 5, 8, 14, 25, 35, 60, 90, 125, 100];

  /// Cumulative posts needed to REACH each stage (stage 0 starts at 0).
  /// → [0, 3, 8, 16, 30, 55, 90, 150, 240, 365].
  static List<int> get reachAt {
    final out = <int>[0];
    for (var i = 0; i < postsPerStage.length - 1; i++) {
      out.add(out.last + postsPerStage[i]);
    }
    return out;
  }

  String get name => stageNames[stage.clamp(0, stageNames.length - 1)];

  int get progressPercent => (progress * 100).round();

  bool get isMax => stage >= stageNames.length - 1;

  /// Build a Level from a lifetime post count.
  factory Level.fromPostCount(int posts) {
    int remaining = posts;
    int stage = 0;
    while (stage < postsPerStage.length - 1 &&
        remaining >= postsPerStage[stage]) {
      remaining -= postsPerStage[stage];
      stage++;
    }
    final needed = postsPerStage[stage];
    final progress = needed == 0 ? 1.0 : (remaining / needed).clamp(0.0, 1.0);
    return Level(stage: stage, progress: progress);
  }

  Map<String, dynamic> toJson() => {'stage': stage, 'progress': progress};

  factory Level.fromJson(Map<String, dynamic> j) => Level(
        stage: j['stage'] as int? ?? 0,
        progress: (j['progress'] as num?)?.toDouble() ?? 0.0,
      );
}
