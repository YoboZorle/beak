/// Progress / level system (2GO-style).
///
/// Every story you post adds progress. When progress fills, you rank up.
/// Stages: Rookie → Amateur → Intermediate → Veteran → Legend → Mythic.
class Level {
  /// 0-based stage index.
  final int stage;

  /// Progress within the current stage, 0.0 - 1.0.
  final double progress;

  const Level({required this.stage, required this.progress});

  static const List<String> stageNames = [
    'Rookie',
    'Amateur',
    'Intermediate',
    'Veteran',
    'Legend',
    'Mythic',
  ];

  /// Posts required to fully clear each stage.
  static const List<int> postsPerStage = [3, 5, 8, 12, 20, 40];

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
