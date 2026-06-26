import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/reaction.dart';
import '../../models/story.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/anime_avatar.dart';
import '../../widgets/countdown.dart';
import '../profile/profile_screen.dart';

/// WhatsApp-style full-screen story.
///
/// Layout is a Column: the media fills the flexible top area, and the
/// engagement bar (reactions + reply + Beak) sits beneath it. With
/// `resizeToAvoidBottomInset: true`, the keyboard simply pushes the engagement
/// bar up and shrinks the media — no manual insets, no overflow.
class StoryViewScreen extends StatefulWidget {
  const StoryViewScreen({
    super.key,
    required this.story,
    this.viewerIsAuthor = false,
  });

  final Story story;
  final bool viewerIsAuthor;

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  Story get story => widget.story;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _reply.dispose();
    _replyFocus.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final src = story.effectiveAudio;
    if (src == null) return;
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      final Source source = src.startsWith('assets/')
          ? AssetSource(src.substring('assets/'.length))
          : src.startsWith('http')
              ? UrlSource(src)
              : DeviceFileSource(src);
      await _player.play(source);
      setState(() => _playing = true);
    }
  }

  void _openProfile() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(user: story.author)),
      );

  Future<void> _beak({ReactionType? reaction, String? message}) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<ChatProvider>().beak(
          story.author,
          reaction: reaction,
          openingMessage: message,
          aboutStoryId: story.id,
          aboutStoryCaption: story.caption,
        );
    final what = reaction != null
        ? 'Reacted ${reaction.emoji}'
        : (message != null ? 'Reply sent' : 'Beak sent');
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      content: Text('$what — ${story.authorUsername} can accept by replying 🐦'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors
        .avatarGradients[story.gradientIndex % AppColors.avatarGradients.length];
    final showCaptionOverlay =
        story.caption.isNotEmpty && story.type != StoryType.textCard;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => _replyFocus.unfocus(),
                    child: _content(colors),
                  ),
                ),
                // top progress + header
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 1,
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _header(),
                      ],
                    ),
                  ),
                ),
                // caption beneath the content (image / voice)
                if (showCaptionOverlay)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _captionOverlay(),
                  ),
              ],
            ),
          ),
          SafeArea(top: false, child: _engagement()),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.viewerIsAuthor ? null : _openProfile,
          child: AnimeAvatar(seed: story.authorAvatarSeed, size: 40),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: widget.viewerIsAuthor ? null : _openProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                          widget.viewerIsAuthor ? 'You' : story.authorUsername,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(story.authorLevel.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Countdown(
                  remaining: story.remaining,
                  prefix: '⏳ ',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (!widget.viewerIsAuthor)
          Text(story.distanceLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }

  Widget _content(List<Color> colors) {
    final img = story.effectiveImage;
    if (story.type == StoryType.imageText && img != null) {
      final ImageProvider provider = img.startsWith('assets/')
          ? AssetImage(img)
          : img.startsWith('http')
              ? NetworkImage(img)
              : FileImage(File(img)) as ImageProvider;
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: provider, fit: BoxFit.cover),
        ),
        child: Container(color: Colors.black.withValues(alpha: 0.15)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: story.type == StoryType.voiceNote
          ? _voicePlayer()
          : story.type == StoryType.textCard
              ? _textCardBody()
              : null,
    );
  }

  Widget _textCardBody() => Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 90, 28, 90),
          child: SingleChildScrollView(
            child: Text(
              story.caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.3,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );

  Widget _captionOverlay() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
          ),
        ),
        child: Text(story.caption,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      );

  Widget _voicePlayer() {
    final total =
        _dur.inMilliseconds == 0 ? story.audioDurationMs : _dur.inMilliseconds;
    final value =
        total == 0 ? 0.0 : (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggleAudio,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2),
              ),
              child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Voice note · ${story.audioDurationLabel}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _engagement() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: widget.viewerIsAuthor
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  'This is your live story — others can react & Beak you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _reactionRow(),
                const SizedBox(height: 10),
                _replyRow(),
              ],
            ),
    );
  }

  Widget _reactionRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final r in kReactions)
            GestureDetector(
              onTap: () => _beak(reaction: r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(r.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _replyRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _reply,
            focusNode: _replyFocus,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.send,
            minLines: 1,
            maxLines: 4,
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              _beak(message: v.trim());
              _reply.clear();
              Navigator.pop(context);
            },
            decoration: InputDecoration(
              hintText: 'Reply privately…',
              hintStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.14),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            _beak();
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: Colors.white, size: 18),
                SizedBox(width: 4),
                Text('Beak',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
