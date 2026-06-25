import 'dart:async';
import 'package:flutter/material.dart';

import '../models/beacon_user.dart';
import '../models/story.dart';
import '../services/backend_service.dart';
import '../services/location_service.dart';

/// Owns nearby discovery. Driven by the backend's live streams so the radar
/// and feed update in real time as people arrive, post, and expire.
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
  }

  final BackendService _backend;
  final LocationService _location;

  late final StreamSubscription _beaconSub;
  late final StreamSubscription _storySub;

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

  Future<void> _refreshStatus() async {
    _hasActivePost = await _backend.hasActivePost();
    _canPost = await _backend.canPostStory();
    _myStoryRemaining = await _backend.myStoryRemaining();
    _myStory = await _backend.myStory();
  }

  /// Initial load + manual / shake rescans.
  Future<void> scan({bool fromShake = false}) async {
    _scanning = true;
    notifyListeners();

    if (fromShake) await _location.refresh();

    _beacons =
        await _backend.nearbyBeacons(lat: _location.lat, lng: _location.lng);
    _stories =
        await _backend.nearbyStories(lat: _location.lat, lng: _location.lng);
    await _refreshStatus();

    _scanning = false;
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
    super.dispose();
  }
}
