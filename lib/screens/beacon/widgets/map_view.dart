import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/story.dart';
import '../../../services/location_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/anime_avatar.dart';

/// The beacon experience, on a real dark map.
///
/// You are your own beacon: your avatar sits at your position with the scan
/// animation pulsing out of you. Live posts are pins around you with rings that
/// drain toward expiry. Beacons in the same close spot **cluster** into a stack;
/// tapping a stack opens a tooltip listing them. The camera fits the selected
/// km range and is constrained so you can't drift far from your beacon.
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

  /// Currently-open stack tooltip (the beacons sharing a close spot).
  List<Story>? _stack;

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
    final mpp = (km * 1000) / 300.0;
    final z = math.log(
            156543.03 * math.cos(widget.myLat * math.pi / 180) / mpp) /
        math.ln2;
    return z.clamp(9.0, 18.0);
  }

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

  List<List<Story>> _cluster(List<Story> pins) {
    final clusters = <List<Story>>[];
    for (final s in pins) {
      List<Story>? hit;
      for (final c in clusters) {
        if (LocationService.distanceMeters(
                c.first.lat, c.first.lng, s.lat, s.lng) <
            80) {
          hit = c;
          break;
        }
      }
      if (hit != null) {
        hit.add(s);
      } else {
        clusters.add([s]);
      }
    }
    return clusters;
  }

  @override
  Widget build(BuildContext context) {
    final pins =
        widget.stories.where((s) => !(s.lat == 0 && s.lng == 0)).toList();
    final clusters = _cluster(pins);

    return Stack(
      children: [
        FlutterMap(
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
            cameraConstraint: CameraConstraint.containCenter(
              bounds: LatLngBounds(
                LatLng(widget.myLat - 0.16, widget.myLng - 0.16),
                LatLng(widget.myLat + 0.16, widget.myLng + 0.16),
              ),
            ),
            onTap: (_, __) => _dismiss(),
            onMapReady: () =>
                showRange(widget.rangeKm.toDouble(), animate: false),
          ),
          children: [
            TileLayer(
              urlTemplate: AppColors.brightness == Brightness.dark
                  ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                  : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.beau.app',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
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
                for (final c in clusters)
                  Marker(
                    point: LatLng(c.first.lat, c.first.lng),
                    width: c.length > 1 ? 76 : 80,
                    height: 96,
                    alignment: Alignment.center,
                    child: c.length > 1
                        ? GestureDetector(
                            onTap: () => setState(() => _stack = c),
                            child: _StackPin(stories: c),
                          )
                        : Tooltip(
                            message: c.first.authorUsername,
                            child: GestureDetector(
                              onTap: () => widget.onTapStory(c.first),
                              child: _BeaconPin(story: c.first),
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
        ),

        // ---- stack tooltip ----
        if (_stack != null) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.25),
            child: _StackTooltip(
              stories: _stack!,
              onPick: (s) {
                _dismiss();
                widget.onTapStory(s);
              },
            ),
          ),
        ],
      ],
    );
  }

  void _dismiss() {
    if (_stack != null) setState(() => _stack = null);
  }
}

/// A floating tooltip listing the beacons stacked at one spot.
class _StackTooltip extends StatelessWidget {
  const _StackTooltip({required this.stories, required this.onPick});
  final List<Story> stories;
  final void Function(Story) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.layers, size: 16, color: AppColors.accentSoft),
                const SizedBox(width: 8),
                Text('${stories.length} beacons here',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.stroke),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: stories.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.stroke),
              itemBuilder: (_, i) {
                final s = stories[i];
                return InkWell(
                  onTap: () => onPick(s),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        AnimeAvatar(seed: s.authorAvatarSeed, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.authorUsername,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  s.caption.isEmpty ? 'Tap to view' : s.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A clustered stack of beacons at one spot: fanned avatars + count badge.
class _StackPin extends StatelessWidget {
  const _StackPin({required this.stories});
  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 0, top: 4, child: _ring(stories[0])),
              Positioned(left: 16, top: 4, child: _ring(stories[1])),
              Positioned(
                right: 2,
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                  child: Text('${stories.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
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
          child: Text('${stories.length} here',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _ring(Story s) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.background, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
        ),
        child: AnimeAvatar(seed: s.authorAvatarSeed, size: 40),
      );
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

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = AppColors.stroke.withValues(alpha: 0.5);
    for (var k = 1; k <= 2; k++) {
      canvas.drawCircle(c, maxR * k / 2.4, base);
    }

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
