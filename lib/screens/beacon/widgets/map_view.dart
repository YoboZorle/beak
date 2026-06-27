import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/story.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/anime_avatar.dart';

/// The beacon experience, on a real dark map.
///
/// You are your own beacon: your avatar sits at your real position with the
/// scan animation (sweep + expanding rings) pulsing out of you. Around you,
/// each live post is a pin at its real coordinate with a ring that drains
/// toward expiry; beacons at the same spot stack on top of each other. The
/// camera is centred on you, fits the selected km range (1 km zooms to a ~1 km
/// view), and is constrained so you can't drift far from your beacon.
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.stories,
    required this.myLat,
    required this.myLng,
    required this.myAvatarSeed,
    required this.rangeKm,
    required this.onTapStory,
  });

  final List<Story> stories;
  final double myLat;
  final double myLng;
  final int myAvatarSeed;
  final int rangeKm;
  final void Function(Story) onTapStory;

  @override
  State<MapView> createState() => MapViewState();
}

class MapViewState extends State<MapView>
    with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();

  late final AnimationController _cam = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _cam, curve: Curves.easeInOut);
  LatLng _fromC = const LatLng(0, 0);
  LatLng _toC = const LatLng(0, 0);
  double _fromZ = 14, _toZ = 14;

  LatLng get _me => LatLng(widget.myLat, widget.myLng);

  @override
  void initState() {
    super.initState();
    _cam.addListener(_tick);
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  void _tick() {
    final t = _curve.value;
    final c = LatLng(_lerp(_fromC.latitude, _toC.latitude, t),
        _lerp(_fromC.longitude, _toC.longitude, t));
    try {
      _controller.move(c, _lerp(_fromZ, _toZ, t));
    } catch (_) {}
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _roughZoom(double km) {
    final mpp = (km * 1000) / 300.0; // ~300px half-viewport
    final z = math.log(
            156543.03 * math.cos(widget.myLat * math.pi / 180) / mpp) /
        math.ln2;
    return z.clamp(9.0, 18.0);
  }

  /// Center on me and fit a `km`-radius view (smoothly).
  void showRange(double km, {bool animate = true}) {
    try {
      final latD = km / 111.0;
      final lngD = km / (111.0 * math.cos(widget.myLat * math.pi / 180).abs());
      final bounds = LatLngBounds(
        LatLng(_me.latitude - latD, _me.longitude - lngD),
        LatLng(_me.latitude + latD, _me.longitude + lngD),
      );
      final fitted = CameraFit.bounds(
              bounds: bounds, padding: const EdgeInsets.all(36))
          .fit(_controller.camera);
      if (animate) {
        _animateTo(_me, fitted.zoom);
      } else {
        _controller.move(_me, fitted.zoom);
      }
    } catch (_) {
      try {
        _controller.move(_me, _roughZoom(km));
      } catch (_) {}
    }
  }

  void recenter() => showRange(widget.rangeKm.toDouble());

  void _animateTo(LatLng c, double z) {
    try {
      _fromC = _controller.camera.center;
      _fromZ = _controller.camera.zoom;
    } catch (_) {
      _fromC = _me;
      _fromZ = z;
    }
    _toC = c;
    _toZ = z;
    _cam
      ..reset()
      ..forward();
  }

  @override
  void didUpdateWidget(covariant MapView old) {
    super.didUpdateWidget(old);
    if (old.rangeKm != widget.rangeKm) {
      showRange(widget.rangeKm.toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pins =
        widget.stories.where((s) => !(s.lat == 0 && s.lng == 0)).toList();

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _me,
        initialZoom: _roughZoom(widget.rangeKm.toDouble()),
        minZoom: 9,
        maxZoom: 18,
        backgroundColor: AppColors.background,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        // Keep the camera near the beacon — no wandering off.
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(
            LatLng(widget.myLat - 0.16, widget.myLng - 0.16),
            LatLng(widget.myLat + 0.16, widget.myLng + 0.16),
          ),
        ),
        onMapReady: () => showRange(widget.rangeKm.toDouble(), animate: false),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.beau.app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            // Me — my own beacon, with the scan animation (kept first + keyed so
            // its animation never restarts as pins come and go around it).
            Marker(
              point: _me,
              width: 200,
              height: 200,
              alignment: Alignment.center,
              child: KeyedSubtree(
                key: const ValueKey('self-beacon'),
                child: _SelfBeacon(seed: widget.myAvatarSeed, size: 200),
              ),
            ),
            // Beacons around me
            for (final s in pins)
              Marker(
                point: LatLng(s.lat, s.lng),
                width: 80,
                height: 92,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => widget.onTapStory(s),
                  child: KeyedSubtree(
                    key: ValueKey(s.id),
                    child: _BeaconPin(story: s),
                  ),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap'),
            TextSourceAttribution('CARTO'),
          ],
        ),
      ],
    );
  }
}

/// My beacon: sweep + expanding rings pulsing out of my avatar.
class _SelfBeacon extends StatefulWidget {
  const _SelfBeacon({required this.seed, required this.size});
  final int seed;
  final double size;

  @override
  State<_SelfBeacon> createState() => _SelfBeaconState();
}

class _SelfBeaconState extends State<_SelfBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _ScanPainter(_c.value),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 3),
              boxShadow: [
                BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    blurRadius: 14,
                    spreadRadius: 1),
              ],
            ),
            child: AnimeAvatar(seed: widget.seed, size: 46),
          ),
        ],
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;

    // faint static rings
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = AppColors.stroke.withValues(alpha: 0.5);
    for (var k = 1; k <= 2; k++) {
      canvas.drawCircle(c, maxR * k / 2.4, base);
    }

    // rotating sweep
    final sweepAngle = t * 2 * math.pi;
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + 0.9,
        colors: [
          AppColors.accent.withValues(alpha: 0.30),
          AppColors.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: maxR));
    canvas.drawCircle(c, maxR, sweep);

    // expanding pulse rings
    for (var k = 0; k < 3; k++) {
      final p = (t + k / 3) % 1.0;
      final r = maxR * p;
      final op = (1 - p) * 0.55;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent.withValues(alpha: op),
      );
    }

    // center glow
    canvas.drawCircle(
        c, 20, Paint()..color = AppColors.accent.withValues(alpha: 0.16));
  }

  @override
  bool shouldRepaint(covariant _ScanPainter old) => old.t != t;
}

/// A nearby beacon pin: avatar + draining countdown ring + name.
class _BeaconPin extends StatelessWidget {
  const _BeaconPin({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final frac =
        (story.remaining.inMilliseconds / Story.lifetime.inMilliseconds)
            .clamp(0.0, 1.0);
    const avatarSize = 44.0;
    const ring = avatarSize + 10;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: ring,
          height: ring,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: ring,
                height: ring,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: frac, end: 0),
                  duration: story.remaining,
                  builder: (_, v, __) => CircularProgressIndicator(
                    value: v,
                    strokeWidth: 3,
                    backgroundColor: Colors.black54,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.accentSoft),
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6)],
                ),
                child:
                    AnimeAvatar(seed: story.authorAvatarSeed, size: avatarSize),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            story.authorUsername,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
