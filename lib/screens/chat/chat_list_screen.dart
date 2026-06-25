import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/anime_avatar.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final pending = chat.incomingPending;
    final chats = chat.chats; // already sorted: most recent first

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          if (chat.unreadTotal > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${chat.unreadTotal} unread',
                    style: const TextStyle(
                        color: AppColors.accentSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (pending.isNotEmpty) ...[
              _sectionLabel('Beak requests · ${pending.length}'),
              ...pending.map((r) => _RequestTile(request: r)),
              const SizedBox(height: 18),
            ],
            _sectionLabel('Conversations'),
            if (chats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                      'No chats yet.\nBeak someone on the beacon to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ...chats.map((c) => _ChatTile(chat: c, unread: chat.unread(c))),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

String _timeLabel(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  final sameDay =
      now.year == t.year && now.month == t.month && now.day == t.day;
  if (sameDay) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${t.day}/${t.month}';
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});
  final ChatRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          AnimeAvatar(seed: request.fromAvatarSeed, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.fromUsername,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(request.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.read<ChatProvider>().decline(request),
            icon: const Icon(Icons.close, color: AppColors.textMuted),
          ),
          IconButton(
            onPressed: () async {
              final c = await context.read<ChatProvider>().accept(request);
              if (!context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: c.id)));
            },
            icon: const Icon(Icons.check_circle, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.unread});
  final Chat chat;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final last = chat.lastMessage;
    final hasUnread = unread > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            AnimeAvatar(seed: chat.peerAvatarSeed, size: 52, hasStory: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chat.peerUsername,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(last?.text ?? 'Say hi 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: hasUnread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_timeLabel(chat.updatedAt),
                    style: TextStyle(
                        color: hasUnread
                            ? AppColors.accentSoft
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (hasUnread)
                  Container(
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: const BoxDecoration(
                        color: AppColors.accent, shape: BoxShape.circle),
                    child: Text('$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
