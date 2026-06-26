import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/chat.dart';
import '../../providers/chat_provider.dart';
import '../../services/backend_service.dart';
import '../../services/storage_service.dart';
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
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text('${chat.unreadTotal} unread',
                    style: const TextStyle(
                        color: AppColors.accentSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          IconButton(
            tooltip: 'Add beacon friend',
            onPressed: () => _openAddByPin(context),
            icon: const Icon(Icons.person_add_alt_1, color: AppColors.accent),
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

  void _openAddByPin(BuildContext context) {
    final myPin = context.read<StorageService>().pin;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddByPinSheet(myPin: myPin),
      ),
    );
  }
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

/// Forces PIN input to uppercase as you type.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// BBM-style "Add beacon friend": share your PIN, enter theirs, send a request.
class _AddByPinSheet extends StatefulWidget {
  const _AddByPinSheet({required this.myPin});
  final String myPin;

  @override
  State<_AddByPinSheet> createState() => _AddByPinSheetState();
}

class _AddByPinSheetState extends State<_AddByPinSheet> {
  final _pin = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = StorageService.normalizePin(_pin.text);
    if (value.length != 8) {
      setState(
          () => _error = 'A Beau PIN is 8 characters (letters & numbers).');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await context.read<ChatProvider>().addByPin(value);
    if (!mounted) return;
    setState(() => _sending = false);

    switch (result.status) {
      case AddFriendStatus.sent:
        navigator.pop();
        messenger.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.accent,
          content: Text(
              'Request sent to ${result.username ?? value} — waiting for them to accept 🤝'),
        ));
        break;
      case AddFriendStatus.self:
        setState(() => _error = 'That\u2019s your own PIN.');
        break;
      case AddFriendStatus.invalid:
        setState(() => _error = 'That doesn\u2019t look like a valid PIN.');
        break;
      case AddFriendStatus.alreadyConnected:
        navigator.pop();
        messenger.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceHigh,
          content: Text(
              'You\u2019re already connected with ${result.username ?? value}.'),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
          const Text('Add a beacon friend',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              'Share your PIN with someone, or enter theirs to send a request. They accept, and you\u2019re connected — no numbers, no names.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),

          // Your PIN to share
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key,
                    color: AppColors.accentSoft, size: 18),
                const SizedBox(width: 10),
                const Text('Your PIN:',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(width: 8),
                Text(widget.myPin,
                    style: const TextStyle(
                        color: AppColors.accentSoft,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.myPin));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.surfaceHigh,
                      duration: Duration(milliseconds: 900),
                      content: Text('PIN copied'),
                    ));
                  },
                  icon: const Icon(Icons.copy,
                      size: 18, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Friend's PIN entry
          TextField(
            controller: _pin,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z]')),
              LengthLimitingTextInputFormatter(8),
              _UpperCaseTextFormatter(),
            ],
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'E.g. K7Q2M9XB',
              hintStyle: const TextStyle(
                  color: AppColors.textMuted, letterSpacing: 2),
              errorText: _error,
              prefixIcon: const Icon(Icons.tag, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.stroke),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18),
              label: Text(_sending ? 'Sending…' : 'Send friend request',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
