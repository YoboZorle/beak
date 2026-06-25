import 'package:flutter/material.dart';

import '../../../models/story.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/anime_avatar.dart';

/// A nearby-story row: avatar + handle + a type glyph and caption on the left,
/// distance + time-ago on the right, tappable to open the story.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  IconData get _typeIcon {
    switch (story.type) {
      case StoryType.voiceNote:
        return Icons.mic;
      case StoryType.imageText:
        return Icons.image;
      case StoryType.textCard:
        return Icons.notes;
    }
  }

  String get _subtitle {
    if (story.type == StoryType.voiceNote) {
      return 'Voice note · ${story.audioDurationLabel}';
    }
    return story.caption;
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors
        .avatarGradients[story.gradientIndex % AppColors.avatarGradients.length];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            AnimeAvatar(seed: story.authorAvatarSeed, size: 44, hasStory: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(story.authorUsername,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Icon(_typeIcon, size: 13, color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(story.distanceLabel,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_ago(story.createdAt),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: gradient),
              ),
              child: const Icon(Icons.north_east, size: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}
