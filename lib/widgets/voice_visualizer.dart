import 'dart:math';

import 'package:flutter/material.dart';

/// A lightweight, lively voice waveform. Bars sit at a stable (per-clip)
/// baseline and bounce while playing; the played portion is highlighted to
/// show progress. One animation controller + a CustomPaint — cheap and smooth,
/// and it only animates while actually playing.
class VoiceVisualizer extends StatefulWidget {
  const VoiceVisualizer({
    super.key,
    required this.playing,
    required this.progress,
    this.bars = 34,
    this.color = Colors.white,
    this.seed = 0,
  });

  final bool playing;
  final double progress; // 0..1
  final int bars;
  final Color color;
  final int seed;

  @override
  State<VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<VoiceVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final List<double> _base = _generate();

  List<double> _generate() {
    final r = Random(widget.seed == 0 ? 7 : widget.seed);
    return List.generate(widget.bars, (i) {
      final x = i / widget.bars;
      // a couple of sine lobes + a little noise → a natural-looking waveform
      final shape = (sin(x * pi * 3) + 1) / 2;
      final v = 0.30 + 0.55 * shape * (0.55 + 0.45 * r.nextDouble());
      return v.clamp(0.12, 1.0);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant VoiceVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: const Size(double.infinity, 56),
        painter: _WavePainter(
          base: _base,
          t: _c.value,
          playing: widget.playing,
          progress: widget.progress.clamp(0.0, 1.0),
          color: widget.color,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.base,
    required this.t,
    required this.playing,
    required this.progress,
    required this.color,
  });

  final List<double> base;
  final double t;
  final bool playing;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = base.length;
    const gap = 3.0;
    final bw = (size.width - (n - 1) * gap) / n;
    final cy = size.height / 2;

    for (var i = 0; i < n; i++) {
      var factor = base[i];
      if (playing) {
        // travelling bounce so the whole bar field feels alive
        final wobble = 0.5 + 0.5 * sin(t * 2 * pi + i * 0.55);
        factor = base[i] * (0.55 + 0.45 * wobble);
      }
      final h = (factor * size.height).clamp(4.0, size.height);
      final x = i * (bw + gap);
      final played = (i + 0.5) / n <= progress;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = played ? color : color.withValues(alpha: 0.28);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, cy - h / 2, bw, h),
        Radius.circular(bw / 2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.t != t || old.progress != progress || old.playing != playing;
}
