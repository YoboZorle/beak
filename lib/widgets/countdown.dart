import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Live ticking countdown (HH:MM:SS) used for the 24h story expiry.
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.remaining,
    this.style,
    this.prefix = '',
    this.onFinished,
  });

  final Duration remaining;
  final TextStyle? style;
  final String prefix;
  final VoidCallback? onFinished;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late Duration _left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _left = widget.remaining;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _left = _left - const Duration(seconds: 1);
        if (_left.isNegative || _left == Duration.zero) {
          _left = Duration.zero;
          _timer?.cancel();
          widget.onFinished?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}${_fmt(_left)}',
      style: widget.style ??
          TextStyle(
            color: AppColors.textSecondary,
            fontFeatures: [FontFeature.tabularFigures()],
            fontSize: 13,
          ),
    );
  }
}
