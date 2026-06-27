import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/story.dart';
import '../../../theme/app_colors.dart';

/// A nearby-story row. The leading circle is a preview of the POST itself
/// (image thumbnail, text-card snippet, or voice glyph) wrapped in a live ring
/// — like a WhatsApp status preview — with the handle, caption, distance and
/// time-ago beside it. Tap to open the full story.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  String get _subtitle {
    if (story.type == StoryType.voiceNote) {
      return 'Voice note · ${story.audioDurationLabel}';
    }
    if (story.type == StoryType.imageText) {
      return story.caption.isEmpty ? 'Photo' : story.caption;
    }
    return story.caption;
  }

  IconData get _typeIcon {
    switch (story.type) {
      case StoryType.voiceNote:
        return Icons.graphic_eq;
      case StoryType.imageText:
        return Icons.photo_camera;
      case StoryType.textCard:
        return Icons.notes;
    }
  }

  ImageProvider? _imageProvider() {
    final img = story.effectiveImage;
    if (story.type != StoryType.imageText || img == null) return null;
    if (img.startsWith('assets/')) return AssetImage(img);
    if (img.startsWith('http')) return NetworkImage(img);
    return FileImage(File(img));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            _PostPreview(story: story, provider: _imageProvider()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(story.authorUsername,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Icon(_typeIcon, size: 13, color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(story.distanceLabel,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_ago(story.createdAt),
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
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

/// The WhatsApp-style preview circle: the post content inside a live ring.
class _PostPreview extends StatelessWidget {
  const _PostPreview({required this.story, required this.provider});

  final Story story;
  final ImageProvider? provider;

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors
        .avatarGradients[story.gradientIndex % AppColors.avatarGradients.length];

    Widget inner;
    if (story.type == StoryType.imageText && provider != null) {
      inner = Image(
        image: provider!,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (_, child, frame, wasSync) {
          if (wasSync || frame != null) return child;
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient)),
          );
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 50,
            height: 50,
            decoration:
                BoxDecoration(gradient: LinearGradient(colors: gradient)),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white70),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          width: 50,
          height: 50,
          decoration:
              BoxDecoration(gradient: LinearGradient(colors: gradient)),
          child: const Icon(Icons.image_not_supported,
              size: 18, color: Colors.white70),
        ),
      );
    } else if (story.type == StoryType.voiceNote) {
      inner = Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(gradient: LinearGradient(colors: gradient)),
        child: const Icon(Icons.graphic_eq, color: Colors.white, size: 22),
      );
    } else {
      inner = Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(gradient: LinearGradient(colors: gradient)),
        child: Text(
          story.caption.isEmpty ? 'Aa' : story.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              height: 1.1,
              fontWeight: FontWeight.w700),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(child: inner),
    );
  }
}
