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
import 'widgets/radar_view.dart';

const List<int> _ranges = [1, 5, 15, 30];

class BeaconScreen extends StatefulWidget {
  const BeaconScreen({super.key});

  @override
  State<BeaconScreen> createState() => _BeaconScreenState();
}

class _BeaconScreenState extends State<BeaconScreen> {
  final _shake = ShakeService();
  int _rangeKm = 5;

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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accent,
        duration: Duration(milliseconds: 900),
        content: Text('📡 Re-scanning the beacon…'),
      ));
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

    final stories = beacon.stories
        .where((s) => s.distanceMeters <= maxMeters)
        .toList();
    final nearCount =
        beacon.beacons.where((b) => b.distanceMeters <= maxMeters).length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () => beacon.scan(fromShake: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleBtn(Icons.bolt,
                          () => beacon.scan(fromShake: true)),
                      const Text('Beacon',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      _rangeMenu(),
                    ],
                  ),
                ),
              ),

              // Radar
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 440,
                  child: me == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent))
                      : RadarView(
                          stories: stories,
                          scanning: beacon.scanning,
                          myAvatarSeed: me.avatarSeed,
                          maxRangeMeters: maxMeters,
                          onTapStory: _openStory,
                        ),
                ),
              ),

              if (!beacon.hasActivePost)
                SliverToBoxAdapter(child: _lockedCta(beacon))
              else ...[
                _headline(nearCount),
                _controls(beacon),
                _rangeRow(),
                _storyFeed(stories),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // -------- gated state: must post to appear + see others ----------------
  Widget _lockedCta(BeaconProvider beacon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        children: [
          const Icon(Icons.podcasts, color: AppColors.accentSoft, size: 40),
          const SizedBox(height: 14),
          const Text('Light up your beacon',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Post a story to appear on the map and see who’s around you. '
            'No post, no presence — that’s how Beau stays alive.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 15),
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

  Widget _headline(int count) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$count',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 56,
                          height: 1,
                          fontWeight: FontWeight.w300)),
                  const SizedBox(width: 12),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: 'Beacons ',
                          style: TextStyle(
                              color: AppColors.accentSoft,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      TextSpan(
                          text: 'Near You',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                    ])),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Within $_rangeKm km · shake to re-scan. Tap an avatar to open their story.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );

  Widget _controls(BeaconProvider beacon) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    beacon.canPost ? AppColors.accent : AppColors.surfaceHigh,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openPost,
              icon: Icon(beacon.canPost ? Icons.add : Icons.podcasts,
                  size: 20),
              label: Text(beacon.canPost
                  ? 'Post your story'
                  : 'Your story is live'),
            ),
          ),
        ),
      );

  Widget _rangeRow() => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nearby stories',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              _rangePills(),
            ],
          ),
        ),
      );

  Widget _storyFeed(List<Story> stories) {
    if (stories.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: Text('No stories within range yet.\nExpand the range or shake to scan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      sliver: SliverList.separated(
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) =>
            ActivityCard(story: stories[i], onTap: () => _openStory(stories[i])),
      ),
    );
  }

  // -------- small widgets ------------------------------------------------
  Widget _circleBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
              color: AppColors.surfaceHigh, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      );

  Widget _rangeMenu() => _circleBtn(Icons.tune, () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Beacon range',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                for (final r in _ranges)
                  RadioListTile<int>(
                    value: r,
                    groupValue: _rangeKm,
                    activeColor: AppColors.accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text('$r km',
                        style: const TextStyle(color: AppColors.textPrimary)),
                    onChanged: (v) {
                      setState(() => _rangeKm = v!);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      });

  Widget _rangePills() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          for (final r in _ranges)
            GestureDetector(
              onTap: () => setState(() => _rangeKm = r),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      _rangeKm == r ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$r',
                    style: TextStyle(
                        color: _rangeKm == r
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
