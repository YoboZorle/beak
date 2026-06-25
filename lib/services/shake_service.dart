import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects a phone "shake" gesture to trigger beacon discovery.
///
/// Uses the accelerometer magnitude with a threshold + cooldown so a single
/// vigorous shake fires once (not a burst). Cheap: only subscribes while the
/// beacon screen is active.
class ShakeService {
  ShakeService({
    this.threshold = 18.0, // m/s^2 beyond gravity-ish
    this.cooldown = const Duration(milliseconds: 1200),
  });

  final double threshold;
  final Duration cooldown;

  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  void start(VoidCallback onShake) {
    _sub ??= accelerometerEventStream().listen((e) {
      final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      // Gravity ~9.8; subtract to get net acceleration.
      final net = (magnitude - 9.8).abs();
      if (net > threshold) {
        final now = DateTime.now();
        if (now.difference(_lastShake) > cooldown) {
          _lastShake = now;
          onShake();
        }
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

typedef VoidCallback = void Function();
