import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../providers/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/anime_avatar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId});
  final String chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatProvider>().markRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    context.read<ChatProvider>().send(widget.chatId, text);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();
    final chat = cp.chatById(widget.chatId);
    final myId = context.watch<SessionProvider>().me?.id;

    if (chat == null) {
      return const Scaffold(body: Center(child: Text('Chat not found')));
    }

    // Mark new incoming messages read while this screen is open (self-terminating).
    if (cp.unread(chat) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) cp.markRead(widget.chatId);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AnimeAvatar(seed: chat.peerAvatarSeed, size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(chat.peerUsername,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text('anonymous beacon',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _EncryptedBanner(),
            Expanded(
              child: chat.messages.isEmpty
                  ? Center(
                      child: Text('Say hi 👋',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      itemCount: chat.messages.length,
                      itemBuilder: (_, i) {
                        final m = chat.messages[i];
                        final mine = m.senderId == myId;
                        final prev = i > 0 ? chat.messages[i - 1] : null;
                        final showDay = prev == null ||
                            !_sameDay(prev.sentAt, m.sentAt);
                        return Column(
                          children: [
                            if (showDay) _DayChip(time: m.sentAt),
                            _Bubble(
                                text: m.text, mine: mine, time: m.sentAt),
                          ],
                        );
                      },
                    ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              style: TextStyle(color: AppColors.textPrimary),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.time});
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = now.year == time.year &&
        now.month == time.month &&
        now.day == time.day;
    final label = today ? 'Today' : '${time.day}/${time.month}/${time.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, required this.time});
  final String text;
  final bool mine;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: mine ? AppColors.accent : AppColors.surfaceHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text,
                style: TextStyle(
                    color: mine ? Colors.white : AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 3),
            Text(_clock(time),
                style: TextStyle(
                    color: mine
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppColors.textMuted,
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _EncryptedBanner extends StatelessWidget {
  const _EncryptedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.surfaceHigh.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 12, color: AppColors.textMuted),
          SizedBox(width: 6),
          Text('Anonymous · end-to-end encrypted',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
