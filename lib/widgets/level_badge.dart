import 'package:flutter/material.dart';
import '../models/level.dart';
import '../theme/app_colors.dart';

/// Shows the 2GO-style rank name + progress within the stage.
class LevelProgress extends StatelessWidget {
  const LevelProgress({super.key, required this.level, this.compact = false});

  final Level level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(level.name,
              style: const TextStyle(
                  color: AppColors.accentSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('${level.progressPercent}%',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(level.name,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('${level.progressPercent}%',
                style: const TextStyle(
                    color: AppColors.accentSoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: level.progress,
            minHeight: 8,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          level.isMax
              ? 'Max rank reached'
              : 'Post a story to rank up → ${Level.stageNames[(level.stage + 1).clamp(0, Level.stageNames.length - 1)]}',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}
