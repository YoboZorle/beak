import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Records short voice notes for voice-note stories, backed by flutter_sound
/// (a self-contained plugin — no broken federated siblings). The 15-second cap
/// is enforced by the UI timer that calls [stop]; this wrapper owns the
/// recorder, requests mic permission, and writes an AAC/m4a file to a temp path.
///
/// Public surface is identical to the previous recorder, so screens are
/// unchanged: hasPermission / start / stop / cancel / dispose.
class VoiceRecorder {
  final FlutterSoundRecorder _rec = FlutterSoundRecorder();
  bool _opened = false;
  String? _path;

  /// Requests the microphone permission (flutter_sound needs it granted first).
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _ensureOpen() async {
    if (_opened) return;
    await _rec.openRecorder();
    _opened = true;
  }

  Future<void> start() async {
    await _ensureOpen();
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/beau_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.startRecorder(toFile: _path, codec: Codec.aacMP4);
  }

  /// Stops and returns the recorded file path (or null if nothing recorded).
  Future<String?> stop() async {
    if (!_opened) return null;
    await _rec.stopRecorder();
    return _path;
  }

  Future<void> cancel() async {
    if (_opened && _rec.isRecording) {
      await _rec.stopRecorder();
    }
    _path = null;
  }

  Future<void> dispose() async {
    if (_opened) {
      await _rec.closeRecorder();
      _opened = false;
    }
  }
}
