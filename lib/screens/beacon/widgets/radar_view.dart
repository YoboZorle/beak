import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../models/story.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/anime_avatar.dart';

/// The live beacon radar. Faint rings + constellation lines, a slow sweep,
/// pulsing colour blips, and — placed by real distance (centre = you, edge =
/// the selected range) — the **posts** of people near you. New posts pop in;
/// tapping a post opens it.
class RadarView extends StatefulWidget {
  const RadarView({
    super.key,
    required this.stories,
    required this.scanning,
    required this.myAvatarSeed,
    required this.maxRangeMeters,
    required this.onTapStory,
  });

  final List<Story> stories;
  final bool scanning;
  final int myAvatarSeed;
  final double maxRangeMeters;
  final void Function(Story) onTapStory;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with TickerProviderStateMixin {
  late final AnimationController _sweep;
  late final AnimationController _ping;

  @override
  void initState() {
    super.initState();
    _sweep =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..repeat();
    _ping = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    _ping.dispose();
    super.dispose();
  }

  double _bearingFor(Story s, int i) {
    final base = (s.authorId.hashCode % 360) * pi / 180.0;
    return base + i * 0.12;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = size.center(Offset.zero);
        final maxR = min(size.width, size.height) / 2 - 44;

        final shown = (widget.stories.toList()
              ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters)))
            .take(7)
            .toList();

        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_sweep, _ping]),
                builder: (_, __) => CustomPaint(
                  painter: _RadarPainter(
                    sweep: _sweep.value,
                    ping: _ping.value,
                    scanning: widget.scanning,
                  ),
                ),
              ),
            ),
            // You, centre.
            Positioned(
              left: center.dx - 32,
              top: center.dy - 32,
              child: AnimeAvatar(
                  seed: widget.myAvatarSeed, size: 64, hasStory: false),
            ),
            for (var i = 0; i < shown.length; i++)
              _placed(center, maxR, shown[i], i),
          ],
        );
      },
    );
  }

  Widget _placed(Offset center, double maxR, Story s, int i) {
    final frac = (s.distanceMeters / widget.maxRangeMeters).clamp(0.14, 1.0);
    final r = 78 + frac * (maxR - 78);
    final bearing = _bearingFor(s, i);
    final dx = center.dx + r * cos(bearing);
    final dy = center.dy + r * sin(bearing);
    final scale = 1.0 - frac * 0.28; // closer = bigger
    final w = 84.0 * scale;
    final h = 60.0 * scale;

    return Positioned(
      left: (dx - w / 2).clamp(2.0, center.dx * 2 - w - 2),
      top: (dy - h / 2).clamp(2.0, center.dy * 2 - h - 2),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(s.id),
        tween: Tween(begin: 0.5, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: GestureDetector(
          onTap: () => widget.onTapStory(s),
          child: _PostChip(story: s, width: w, height: h),
        ),
      ),
    );
  }
}

/// A small live-post token on the radar: shows the post itself (text snippet,
/// image thumb, or voice glyph) rather than the author's avatar.
class _PostChip extends StatelessWidget {
  const _PostChip({required this.story, required this.width, required this.height});

  final Story story;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors
        .avatarGradients[story.gradientIndex % AppColors.avatarGradients.length];
    final img = story.effectiveImage;
    final isImage = story.type == StoryType.imageText && img != null;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentSoft.withValues(alpha: 0.9), width: 1.5),
        gradient: isImage
            ? null
            : LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
        image: isImage
            ? DecorationImage(
                image: img.startsWith('http')
                    ? NetworkImage(img)
                    : FileImage(File(img)) as ImageProvider,
                fit: BoxFit.cover)
            : null,
        boxShadow: [
          BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 0.5),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: isImage
            ? BoxDecoration(color: Colors.black.withValues(alpha: 0.28))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 12, color: Colors.white.withValues(alpha: 0.95)),
            const Spacer(),
            Text(
              _snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                height: 1.1,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    switch (story.type) {
      case StoryType.voiceNote:
        return Icons.mic;
      case StoryType.imageText:
        return Icons.image;
      case StoryType.textCard:
        return Icons.notes;
    }
  }

  String get _snippet {
    if (story.type == StoryType.voiceNote) {
      return 'Voice · ${story.audioDurationLabel}';
    }
    final c = story.caption.trim();
    if (c.isEmpty) return story.authorUsername;
    return c.length <= 24 ? c : '${c.substring(0, 24)}…';
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.sweep,
    required this.ping,
    required this.scanning,
  });

  final double sweep;
  final double ping;
  final bool scanning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = min(size.width, size.height) / 2 - 24;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.stroke.withValues(alpha: 0.6);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxR * i / 4, ringPaint);
    }

    final linePaint = Paint()
      ..strokeWidth = 0.8
      ..color = AppColors.stroke.withValues(alpha: 0.4);
    final rng = Random(7);
    for (var i = 0; i < 10; i++) {
      final a1 = rng.nextDouble() * 2 * pi;
      final a2 = a1 + (rng.nextDouble() - 0.5);
      final r1 = maxR * (0.3 + rng.nextDouble() * 0.7);
      final r2 = maxR * (0.3 + rng.nextDouble() * 0.7);
      canvas.drawLine(
        center + Offset(r1 * cos(a1), r1 * sin(a1)),
        center + Offset(r2 * cos(a2), r2 * sin(a2)),
        linePaint,
      );
    }

    final sweepAngle = sweep * 2 * pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + 0.9,
        colors: [
          AppColors.accent.withValues(alpha: scanning ? 0.32 : 0.16),
          AppColors.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, sweepPaint);

    final blipRng = Random(21);
    for (var i = 0; i < AppColors.blips.length * 2; i++) {
      final a = blipRng.nextDouble() * 2 * pi;
      final rr = maxR * (0.25 + blipRng.nextDouble() * 0.7);
      final pos = center + Offset(rr * cos(a), rr * sin(a));
      final color = AppColors.blips[i % AppColors.blips.length];
      final pulse = 0.5 + 0.5 * sin((ping + i / 6) * 2 * pi);
      canvas.drawCircle(
          pos, 2.2 + pulse * 1.8, Paint()..color = color.withValues(alpha: 0.9));
      canvas.drawCircle(pos, 7 + pulse * 4,
          Paint()..color = color.withValues(alpha: 0.15 * pulse));
    }

    canvas.drawCircle(
      center,
      18 + ping * 10,
      Paint()..color = AppColors.accent.withValues(alpha: 0.10 * (1 - ping)),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.sweep != sweep || old.ping != ping || old.scanning != scanning;
}
