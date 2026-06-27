import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import '../../providers/beacon_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/shake_service.dart';
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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accent,
        duration: Duration(milliseconds: 900),
        content: Text('📡 Re-scanning the beacon…'),
      ));
  }

  void _openStory(Story s) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => StoryViewScreen(story: s)));

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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _header(beacon),
            const SizedBox(height: 14),
            _beaconCard(me, beacon, stories),
            const SizedBox(height: 18),
            _countRow(nearCount),
            const SizedBox(height: 12),
            _rangePills(),
            const SizedBox(height: 16),
            _postButton(beacon),
            const SizedBox(height: 22),
            if (beacon.hasActivePost)
              _feed(stories)
            else
              _locked(),
          ],
        ),
      ),
    );
  }

  // ---- header -----------------------------------------------------------
  Widget _header(BeaconProvider beacon) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Beacon',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              Text(beacon.hasFix ? 'Live · near you' : 'Locating you…',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        _circleBtn(Icons.my_location, () => _mapKey.currentState?.recenter()),
        const SizedBox(width: 8),
        _circleBtn(
            Icons.bolt, () => context.read<BeaconProvider>().scan(fromShake: true)),
      ],
    );
  }

  // ---- the beacon (animated map) ----------------------------------------
  Widget _beaconCard(me, BeaconProvider beacon, List<Story> stories) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.stroke),
        ),
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
    );
  }

  Widget _countRow(int nearCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$nearCount',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 42,
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
    );
  }

  Widget _rangePills() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.stroke)),
      child: Row(
        children: [
          for (final r in _ranges)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _rangeKm = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        _rangeKm == r ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$r km',
                      style: TextStyle(
                          color: _rangeKm == r
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _postButton(BeaconProvider beacon) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor:
              beacon.canPost ? AppColors.accent : AppColors.surfaceHigh,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _openPost,
        icon: Icon(beacon.canPost ? Icons.add : Icons.podcasts, size: 20),
        label: Text(beacon.canPost ? 'Post your story' : 'Your story is live',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _feed(List<Story> stories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nearby stories',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
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
                child: ActivityCard(story: s, onTap: () => _openStory(s)),
              )),
      ],
    );
  }

  Widget _locked() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: [
          const Icon(Icons.podcasts, color: AppColors.accentSoft, size: 34),
          const SizedBox(height: 12),
          const Text('Light up your beacon',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Post a story to drop your beacon on the map and reveal everyone around you. No post, no presence.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openPost,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Post your story',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.stroke),
          ),
          child: Icon(icon, size: 19, color: AppColors.textPrimary),
        ),
      );
}
