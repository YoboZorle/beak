import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/backend_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/anime_avatar.dart';
import '../beacon/beacon_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    BeaconScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Surface "push" events as a top banner (simulates FCM in-app display).
    final event = context.watch<SessionProvider>().lastEvent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (event != null && mounted) {
        _showEventBanner(event);
        context.read<SessionProvider>().consumeEvent();
      }
    });

    final pending = context.watch<ChatProvider>().pendingCount;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.accent.withOpacity(0.18),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            height: 64,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.radar_outlined, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.radar, color: AppColors.accent),
                  label: 'Beacon'),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pending > 0,
                    label: Text('$pending'),
                    child: const Icon(Icons.chat_bubble_outline,
                        color: AppColors.textSecondary),
                  ),
                  selectedIcon:
                      const Icon(Icons.chat_bubble, color: AppColors.accent),
                  label: 'Chats'),
              const NavigationDestination(
                  icon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.person, color: AppColors.accent),
                  label: 'You'),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventBanner(NearbyEvent e) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.stroke)),
        content: Row(
          children: [
            AnimeAvatar(seed: e.avatarSeed, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(e.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (e.type == NearbyEventType.chatRequest ||
                e.type == NearbyEventType.messageReceived)
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  setState(() => _index = 1);
                },
                child: const Text('View',
                    style: TextStyle(color: AppColors.accentSoft)),
              ),
          ],
        ),
      ),
    );
  }
}
