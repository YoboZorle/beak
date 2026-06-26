import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/beacon_user.dart';
import '../../models/level.dart';
import '../../providers/beacon_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/anime_avatar.dart';
import '../../widgets/countdown.dart';
import '../../widgets/level_badge.dart';
import '../story/story_view_screen.dart';

/// Two modes:
///  * own profile (default) — your PIN, level, live-story status, lifetime.
///  * public profile ([user] set) — another beacon's card + a Beak button.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.user});

  /// When non-null, show this other user's public profile.
  final BeaconUser? user;

  bool get _isPublic => user != null;

  @override
  Widget build(BuildContext context) {
    return _isPublic ? _publicProfile(context) : _ownProfile(context);
  }

  // --------------------------------------------------------------- public
  Widget _publicProfile(BuildContext context) {
    final u = user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              AnimeAvatar(seed: u.avatarSeed, size: 110, hasStory: u.hasStory),
              const SizedBox(height: 16),
              Text(u.username,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${u.level.name} · ${u.distanceLabel}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: LevelProgress(level: u.level),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await context.read<ChatProvider>().beak(u);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.surfaceHigh,
                      content: Text('Beak sent to ${u.username} 🐦'),
                    ));
                  },
                  icon: const Icon(Icons.bolt, size: 20),
                  label: const Text('Beak — request a chat',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- own
  Widget _ownProfile(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final beacon = context.watch<BeaconProvider>();
    final pin = context.read<StorageService>().pin;
    final postCount = context.read<StorageService>().postCount;
    final me = session.me;

    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const SizedBox(height: 8),
                  Center(child: AnimeAvatar(seed: me.avatarSeed, size: 110)),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(me.username,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 12),
                  _pinCard(pin),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showLevels(context, session.level),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Column(
                        children: [
                          LevelProgress(level: session.level),
                          const SizedBox(height: 12),
                          const Divider(color: AppColors.stroke, height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.military_tech,
                                  size: 16, color: AppColors.accentSoft),
                              SizedBox(width: 6),
                              Text('See all levels',
                                  style: TextStyle(
                                      color: AppColors.accentSoft,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Icon(Icons.chevron_right,
                                  size: 18, color: AppColors.accentSoft),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _storyCard(context, beacon),
                  const SizedBox(height: 24),
                  const Text('Lifetime',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _stat('Posts', '$postCount'),
                      const SizedBox(width: 12),
                      _stat('Rank', session.level.name),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _pinCard(String pin) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            const Icon(Icons.vpn_key, color: AppColors.accentSoft, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Beau PIN',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(pin,
                    style: const TextStyle(
                        color: AppColors.accentSoft,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.lock, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Text('this device',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      );

  Widget _storyCard(BuildContext context, BeaconProvider beacon) {
    final live = !beacon.canPost;
    final myStory = beacon.myStory;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: live && myStory != null
          ? () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  StoryViewScreen(story: myStory, viewerIsAuthor: true)))
          : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Icon(live ? Icons.podcasts : Icons.add_circle_outline,
                color: AppColors.accentSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(live ? 'Story is live' : 'No live story',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  if (!live)
                    const Text('You can post one story every 5 min (demo).',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))
                  else if (beacon.myStoryRemaining != null)
                    Countdown(
                      remaining: beacon.myStoryRemaining!,
                      prefix: 'Tap to view · disappears in ',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (live && myStory != null)
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      );

  // ---- levels modal -----------------------------------------------------
  void _showLevels(BuildContext context, Level current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.stroke,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Levels',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  'You\u2019re a ${current.name}. Post stories to climb the ranks.',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              for (var i = 0; i < Level.stageNames.length; i++)
                _levelTile(i, current),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelTile(int i, Level current) {
    final cleared = i < current.stage;
    final isCurrent = i == current.stage;
    final Color color = cleared
        ? const Color(0xFF49D17A)
        : isCurrent
            ? AppColors.accent
            : AppColors.textMuted;
    final IconData icon = cleared
        ? Icons.check_circle
        : isCurrent
            ? Icons.star
            : Icons.lock;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isCurrent ? AppColors.accent : AppColors.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(Level.stageNames[i],
                        style: TextStyle(
                            color: i > current.stage
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('You\u2019re here',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                    i == 0
                        ? 'Starting rank'
                        : 'Reach at ${Level.reachAt[i]} posts',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                if (isCurrent) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: current.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.stroke,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${current.progressPercent}% to next rank',
                      style: const TextStyle(
                          color: AppColors.accentSoft, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
