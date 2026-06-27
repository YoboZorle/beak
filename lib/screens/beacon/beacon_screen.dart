import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import '../../providers/beacon_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/shake_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../story/post_story_screen.dart';
import '../story/story_view_screen.dart';
import 'widgets/activity_card.dart';
import 'widgets/map_view.dart';

const List<int> _ranges = [1, 5, 15, 30];

class BeaconScreen extends StatefulWidget {
  const BeaconScreen({super.key});

  @override
  State<BeaconScreen> createState() => _BeaconScreenState();
}

class _BeaconScreenState extends State<BeaconScreen> {
  final _shake = ShakeService();
  final _mapKey = GlobalKey<MapViewState>();
  int _rangeKm = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BeaconProvider>().scan();
      _shake.start(_onShake);
    });
  }

  @override
  void dispose() {
    _shake.stop();
    super.dispose();
  }

  void _onShake() {
    if (!mounted) return;
    context.read<BeaconProvider>().scan(fromShake: true);
    _mapKey.currentState?.recenter();
  }

  void _openStory(Story s) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoryViewScreen(story: s)),
      );

  void _openPost() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const PostStoryScreen()));

  @override
  Widget build(BuildContext context) {
    final beacon = context.watch<BeaconProvider>();
    final me = context.watch<SessionProvider>().me;
    final maxMeters = _rangeKm * 1000.0;

    final stories =
        beacon.stories.where((s) => s.distanceMeters <= maxMeters).toList();
    final nearCount =
        beacon.beacons.where((b) => b.distanceMeters <= maxMeters).length;
    final live = beacon.hasActivePost;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ---- map ----
          Positioned.fill(
            child: me == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : MapView(
                    key: _mapKey,
                    stories: stories,
                    myLat: beacon.myLat,
                    myLng: beacon.myLng,
                    myAvatarSeed: me.avatarSeed,
                    rangeKm: _rangeKm,
                    onTapStory: _openStory,
                  ),
          ),

          // ---- top scrim for legibility ----
          IgnorePointer(
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0.9),
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ---- top bar + range ----
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  _topBar(beacon, live),
                  const SizedBox(height: 12),
                  _rangeSelector(),
                ],
              ),
            ),
          ),

          // ---- bottom: live sheet OR "dark beacon" hero ----
          if (live)
            _liveSheet(nearCount, stories, beacon)
          else
            _darkHero(context),
        ],
      ),
    );
  }

  // ---- top bar ----------------------------------------------------------
  Widget _topBar(BeaconProvider beacon, bool live) {
    return _glass(
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [AppColors.accent, AppColors.accentSoft],
              ).createShader(r),
              child: const Text('beau',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ),
            const SizedBox(width: 10),
            _statusPill(beacon, live),
            const Spacer(),
            _miniBtn(Icons.my_location, () => _mapKey.currentState?.recenter()),
            const SizedBox(width: 8),
            _miniBtn(Icons.refresh,
                () => context.read<BeaconProvider>().scan(fromShake: true)),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(BeaconProvider beacon, bool live) {
    final (color, label) = !beacon.hasFix
        ? (AppColors.textMuted, 'Locating…')
        : live
            ? (const Color(0xFF49D17A), 'Live')
            : (AppColors.accentSoft, 'Dark');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: Colors.white12, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      );

  Widget _rangeSelector() {
    return _glass(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in _ranges)
              GestureDetector(
                onTap: () => setState(() => _rangeKm = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: _rangeKm == r
                        ? const LinearGradient(
                            colors: [AppColors.accent, Color(0xFF3A2BD8)])
                        : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$r km',
                      style: TextStyle(
                          color: _rangeKm == r
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- live sheet -------------------------------------------------------
  Widget _liveSheet(int nearCount, List<Story> stories, BeaconProvider beacon) {
    return DraggableScrollableSheet(
      initialChildSize: 0.26,
      minChildSize: 0.12,
      maxChildSize: 0.82,
      builder: (ctx, sc) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.92),
              border: const Border(top: BorderSide(color: AppColors.stroke)),
            ),
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                _grabber(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$nearCount',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 40,
                            height: 1,
                            fontWeight: FontWeight.w300)),
                    const SizedBox(width: 10),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('beacons near you',
                          style: TextStyle(
                              color: AppColors.accentSoft,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                Text('Within $_rangeKm km · tap a pin to open it.',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 14),
                _gradientButton(
                  icon: beacon.canPost ? Icons.add : Icons.podcasts,
                  label: beacon.canPost
                      ? 'Post your story'
                      : 'Your beacon is live',
                  onTap: _openPost,
                  active: beacon.canPost,
                ),
                const SizedBox(height: 18),
                const Text('Nearby stories',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (stories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                          'No beacons within range yet.\nExpand the range or shake to scan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...stories.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child:
                            ActivityCard(story: s, onTap: () => _openStory(s)),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- dark-beacon hero (not posted) ------------------------------------
  Widget _darkHero(BuildContext context) {
    final posted = context.read<StorageService>().postCount > 0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: _glass(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.podcasts,
                          size: 14, color: AppColors.accentSoft),
                      SizedBox(width: 6),
                      Text('Beacon blinking · waiting for you',
                          style: TextStyle(
                              color: AppColors.accentSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(posted ? 'Your beacon ended' : 'Your beacon is dark',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  posted
                      ? 'Your last story expired. Post again to reappear on the map and reconnect with people near you.'
                      : 'Post a story to light up your beacon, drop onto the map, and reveal everyone around you. No post, no presence.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5),
                ),
                const SizedBox(height: 20),
                _gradientButton(
                  icon: Icons.add,
                  label: posted ? 'Light it up again' : 'Drop your beacon',
                  onTap: _openPost,
                  active: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- shared bits ------------------------------------------------------
  Widget _grabber() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.stroke, borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _gradientButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool active,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [AppColors.accent, Color(0xFF3A2BD8)])
                  : null,
              color: active ? null : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glass({required double radius, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.stroke),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
