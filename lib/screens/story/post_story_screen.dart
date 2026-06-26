import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import '../../providers/beacon_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/audio_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/countdown.dart';

const int _maxVoiceMs = 15000;

class PostStoryScreen extends StatefulWidget {
  const PostStoryScreen({super.key});

  @override
  State<PostStoryScreen> createState() => _PostStoryScreenState();
}

class _PostStoryScreenState extends State<PostStoryScreen> {
  StoryType _type = StoryType.textCard;
  int _gradient = 0;
  final _caption = TextEditingController();

  String? _imagePath;

  final _recorder = VoiceRecorder();
  final _preview = AudioPlayer();
  bool _recording = false;
  bool _playing = false;
  int _elapsedMs = 0;
  Timer? _recTimer;
  String? _audioPath;
  int _audioMs = 0;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _preview.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    _recTimer?.cancel();
    _recorder.dispose();
    _preview.dispose();
    super.dispose();
  }

  // ---- media actions ----------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: source, maxWidth: 1440, imageQuality: 85);
      if (x != null) {
        setState(() {
          _imagePath = x.path;
          _type = StoryType.imageText;
        });
      }
    } catch (_) {
      _toast('Could not open the picker.');
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecord();
      return;
    }
    if (!await _recorder.hasPermission()) {
      _toast('Microphone permission needed for voice notes.');
      return;
    }
    setState(() {
      _audioPath = null;
      _audioMs = 0;
      _elapsedMs = 0;
      _recording = true;
    });
    await _recorder.start();
    _recTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() => _elapsedMs += 100);
      if (_elapsedMs >= _maxVoiceMs) _stopRecord();
    });
  }

  Future<void> _stopRecord() async {
    _recTimer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _recording = false;
      _audioPath = path;
      _audioMs = _elapsedMs.clamp(0, _maxVoiceMs);
    });
  }

  Future<void> _togglePlay() async {
    if (_audioPath == null) return;
    if (_playing) {
      await _preview.pause();
      setState(() => _playing = false);
    } else {
      await _preview.play(DeviceFileSource(_audioPath!));
      setState(() => _playing = true);
    }
  }

  bool get _canPost {
    switch (_type) {
      case StoryType.textCard:
        return _caption.text.trim().isNotEmpty;
      case StoryType.imageText:
        return _imagePath != null;
      case StoryType.voiceNote:
        return _audioPath != null;
    }
  }

  String? get _emptyHint {
    if (_canPost) return null;
    switch (_type) {
      case StoryType.textCard:
        return 'Type something to post your status.';
      case StoryType.imageText:
        return 'Pick a photo to post.';
      case StoryType.voiceNote:
        return 'Record a voice note to post.';
    }
  }

  Future<void> _post() async {
    if (!_canPost || _posting) return;
    setState(() => _posting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifications = context.read<NotificationService>();
    final caption = _caption.text.trim();
    await context.read<BeaconProvider>().postStory(
          type: _type,
          gradientIndex: _gradient,
          caption: caption,
          imagePath: _imagePath,
          audioPath: _audioPath,
          audioDurationMs: _audioMs,
        );
    await context.read<SessionProvider>().refreshLevel();
    // Schedule OS-level notifications that fire over the next few minutes —
    // even if the app is closed — so activity reaches the device.
    notifications.scheduleNearbyTeasers();
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.accent,
      content: Text('Story posted — your beacon is live for 5 min 📡'),
    ));
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceHigh,
            content: Text(m)),
      );

  @override
  Widget build(BuildContext context) {
    final beacon = context.watch<BeaconProvider>();

    if (!beacon.canPost) return _liveGate(beacon);

    return Scaffold(
      appBar: AppBar(title: const Text('New story')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _typeSelector(),
              const SizedBox(height: 14),
              Expanded(child: _preview_(_gradientColors())),
              const SizedBox(height: 14),
              if (_type == StoryType.textCard) _gradientChooser(),
              if (_type == StoryType.imageText) _imageButtons(),
              if (_type == StoryType.voiceNote) _voiceControls(),
              const SizedBox(height: 12),
              TextField(
                controller: _caption,
                onChanged: (_) => setState(() {}),
                maxLength: 120,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: _type == StoryType.textCard
                      ? 'Type your status…'
                      : 'Add a caption (optional)',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  counterStyle: const TextStyle(color: AppColors.textMuted),
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
              if (_emptyHint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_emptyHint!,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _canPost ? AppColors.accent : AppColors.surfaceHigh,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _canPost && !_posting ? _post : null,
                  child: _posting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Post to beacon (5 min)',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _gradientColors() =>
      AppColors.avatarGradients[_gradient % AppColors.avatarGradients.length];

  // ---- pieces -----------------------------------------------------------
  Widget _typeSelector() {
    Widget seg(StoryType t, IconData icon, String label) {
      final sel = _type == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _type = t),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.accent : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 20,
                    color: sel ? Colors.white : AppColors.textSecondary),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg(StoryType.textCard, Icons.notes, 'Text'),
        seg(StoryType.imageText, Icons.image, 'Photo'),
        seg(StoryType.voiceNote, Icons.mic, 'Voice'),
      ],
    );
  }

  Widget _preview_(List<Color> colors) {
    final hasImage = _type == StoryType.imageText && _imagePath != null;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: hasImage
            ? null
            : LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
        image: hasImage
            ? DecorationImage(
                image: FileImage(File(_imagePath!)), fit: BoxFit.cover)
            : null,
      ),
      child: Stack(
        children: [
          // Text card: the caption IS the content, centred (WhatsApp text status).
          if (_type == StoryType.textCard)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  _caption.text.isEmpty ? 'Type your status…' : _caption.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _caption.text.isEmpty
                          ? Colors.white54
                          : Colors.white,
                      fontSize: 26,
                      height: 1.25,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          // Voice: a centred glyph over the gradient.
          if (_type == StoryType.voiceNote)
            Center(
              child: Icon(
                  _recording ? Icons.graphic_eq : Icons.multitrack_audio,
                  size: 72,
                  color: Colors.white70),
            ),
          // Image / voice: caption shown BENEATH the content as a bottom bar.
          if (_type != StoryType.textCard && _caption.text.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55)
                    ],
                  ),
                ),
                child: Text(_caption.text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradientChooser() => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: AppColors.avatarGradients.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final g = AppColors.avatarGradients[i];
            final selected = i == _gradient;
            return GestureDetector(
              onTap: () => setState(() => _gradient = i),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: g),
                  border: Border.all(
                      color: selected
                          ? AppColors.textPrimary
                          : Colors.transparent,
                      width: 2),
                ),
              ),
            );
          },
        ),
      );

  Widget _imageButtons() => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Gallery'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Camera'),
            ),
          ),
        ],
      );

  Widget _voiceControls() {
    final secs = (_elapsedMs / 1000).toStringAsFixed(1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_recording)
                CircularProgressIndicator(
                  value: _elapsedMs / _maxVoiceMs,
                  color: AppColors.accent,
                  backgroundColor: AppColors.surfaceHigh,
                ),
              GestureDetector(
                onTap: _toggleRecord,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _recording ? AppColors.blips[2] : AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_recording ? Icons.stop : Icons.mic,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                _recording
                    ? 'Recording  $secs s / 15s'
                    : _audioPath != null
                        ? 'Recorded ${(_audioMs / 1000).toStringAsFixed(1)}s'
                        : 'Tap to record (max 15s)',
                style: const TextStyle(color: AppColors.textPrimary)),
            if (_audioPath != null && !_recording)
              TextButton.icon(
                onPressed: _togglePlay,
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
                    size: 18, color: AppColors.accentSoft),
                label: Text(_playing ? 'Pause' : 'Play preview',
                    style: const TextStyle(color: AppColors.accentSoft)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _liveGate(BeaconProvider beacon) => Scaffold(
        appBar: AppBar(title: const Text('Your story')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_bottom,
                    size: 56, color: AppColors.accentSoft),
                const SizedBox(height: 16),
                const Text('You already have a live story',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                    'You can post one story every 5 minutes (demo). It disappears when the timer ends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                if (beacon.myStoryRemaining != null)
                  Countdown(
                    remaining: beacon.myStoryRemaining!,
                    prefix: 'Disappears in  ',
                    style: const TextStyle(
                        color: AppColors.accentSoft,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
              ],
            ),
          ),
        ),
      );
}
