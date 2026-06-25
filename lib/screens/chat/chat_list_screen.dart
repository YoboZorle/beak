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
    final chats = chat.chats;

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (pending.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 10),
                child: Text('Beak requests',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              ...pending.map((r) => _RequestTile(request: r)),
              const SizedBox(height: 18),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 10),
              child: Text('Conversations',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
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
              ...chats.map((c) => _ChatTile(chat: c)),
          ],
        ),
      ),
    );
  }
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
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
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
  const _ChatTile({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final last = chat.lastMessage;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            AnimeAvatar(seed: chat.peerAvatarSeed, size: 50),
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
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
