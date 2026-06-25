import 'dart:async';
import 'package:flutter/material.dart';

import '../models/beacon_user.dart';
import '../models/story.dart';
import '../services/backend_service.dart';
import '../services/location_service.dart';

/// Owns nearby discovery. Driven by the backend's live streams (so the radar
/// and feed update in realtime as people post and expire) AND by the device's
/// live GPS (so distances stay true as the user moves).
class BeaconProvider extends ChangeNotifier {
  BeaconProvider(this._backend, this._location) {
    _beaconSub = _backend.beaconStream().listen((b) {
      _beacons = b;
      _refreshStatus();
      notifyListeners();
    });
    _storySub = _backend.storyStream().listen((s) {
      _stories = s;
      notifyListeners();
    });
    // Live location → recompute proximity as the user moves (no UI flicker).
    _locSub = _location.watch().listen(
      (pos) {
        _location.applyPosition(pos);
        scan(silent: true);
      },
      onError: (_) {/* permission/service off — fall back silently */},
      cancelOnError: false,
    );
  }

  final BackendService _backend;
  final LocationService _location;

  late final StreamSubscription _beaconSub;
  late final StreamSubscription _storySub;
  StreamSubscription? _locSub;

  List<BeaconUser> _beacons = [];
  List<Story> _stories = [];
  bool _scanning = false;

  bool _hasActivePost = false;
  bool _canPost = true;
  Duration? _myStoryRemaining;
  Story? _myStory;

  List<BeaconUser> get beacons => _beacons;
  List<Story> get stories => _stories;
  bool get scanning => _scanning;
  bool get hasActivePost => _hasActivePost;
  bool get canPost => _canPost;
  Duration? get myStoryRemaining => _myStoryRemaining;
  Story? get myStory => _myStory;
  int get nearbyCount => _beacons.length;
  bool get locating => _location.permissionGranted && !_location.hasFix;
  bool get hasFix => _location.hasFix;

  Future<void> _refreshStatus() async {
    _hasActivePost = await _backend.hasActivePost();
    _canPost = await _backend.canPostStory();
    _myStoryRemaining = await _backend.myStoryRemaining();
    _myStory = await _backend.myStory();
  }

  /// Initial load, shake rescans, and silent location-driven refreshes.
  Future<void> scan({bool fromShake = false, bool silent = false}) async {
    if (!silent) {
      _scanning = true;
      notifyListeners();
    }
    if (fromShake) await _location.refresh();

    _beacons =
        await _backend.nearbyBeacons(lat: _location.lat, lng: _location.lng);
    _stories =
        await _backend.nearbyStories(lat: _location.lat, lng: _location.lng);
    await _refreshStatus();

    if (!silent) _scanning = false;
    notifyListeners();
  }

  Future<Story> postStory({
    required StoryType type,
    required int gradientIndex,
    required String caption,
    String? imagePath,
    String? audioPath,
    int audioDurationMs = 0,
  }) async {
    final story = await _backend.postStory(
      type: type,
      gradientIndex: gradientIndex,
      caption: caption,
      imagePath: imagePath,
      audioPath: audioPath,
      audioDurationMs: audioDurationMs,
      lat: _location.lat,
      lng: _location.lng,
    );
    await _refreshStatus();
    notifyListeners();
    return story;
  }

  @override
  void dispose() {
    _beaconSub.cancel();
    _storySub.cancel();
    _locSub?.cancel();
    super.dispose();
  }
}
