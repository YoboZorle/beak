import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/beacon_user.dart';
import '../../providers/beacon_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/anime_avatar.dart';
import '../profile/profile_screen.dart';

/// Local leaderboard — people near you ranked by level (highest first), with
/// your own position highlighted. Tap anyone to view them or Beak to chat.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final beacon = context.watch<BeaconProvider>();
    final myId = context.watch<SessionProvider>().me?.id;
    final ranked = beacon.leaderboard;
    final myRank = ranked.indexWhere((u) => u.id == myId);

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () => beacon.scan(),
          child: ranked.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text('No one ranked nearby yet.',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _myPositionCard(myRank, ranked.length),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                      child: Text('Top beacons near you',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                    for (var i = 0; i < ranked.length; i++)
                      _row(context, i, ranked[i], ranked[i].id == myId),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _myPositionCard(int myRank, int total) {
    final pos = myRank < 0 ? '—' : '#${myRank + 1}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.accent, Color(0xFF3A2BD8)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your position',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text('$pos of $total near you',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i, BeaconUser u, bool isMe) {
    final rank = i + 1;
    final medal = switch (rank) {
      1 => const Color(0xFFFFD166),
      2 => const Color(0xFFC9CBD6),
      3 => const Color(0xFFFF8A3D),
      _ => AppColors.textMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.surfaceHigh : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMe ? AppColors.accent : AppColors.stroke),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: medal,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          AnimeAvatar(seed: u.avatarSeed, size: 44, hasStory: u.hasStory),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(isMe ? '${u.username} (you)' : u.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    isMe
                        ? u.level.name
                        : '${u.level.name} · ${u.distanceLabel}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (!isMe)
            IconButton(
              onPressed: () async {
                await context.read<ChatProvider>().beak(u);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.surfaceHigh,
                  content: Text('Beak sent to ${u.username} 🐦'),
                ));
              },
              icon: const Icon(Icons.bolt, color: AppColors.accent),
              tooltip: 'Beak',
            ),
          if (!isMe)
            IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(user: u))),
              icon: const Icon(Icons.chevron_right,
                  color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}
