import 'dart:async';
import 'package:flutter/material.dart';

import '../models/beacon_user.dart';
import '../models/level.dart';
import '../services/backend_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

/// Owns the device identity, location, level, and the push-event stream.
/// Every nearby event becomes a real local notification *and* an in-app
/// banner, keeping the two surfaces consistent.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._backend, this._location, this._notifications);

  final BackendService _backend;
  final LocationService _location;
  final NotificationService _notifications;

  BeaconUser? _me;
  Level _level = const Level(stage: 0, progress: 0);
  NearbyEvent? _lastEvent;
  StreamSubscription<NearbyEvent>? _eventSub;
  bool _ready = false;

  BeaconUser? get me => _me;
  Level get level => _level;
  NearbyEvent? get lastEvent => _lastEvent;
  bool get ready => _ready;
  double get lat => _location.lat;
  double get lng => _location.lng;

  Future<void> bootstrap() async {
    await _location.refresh();
    _me = await _backend.ensureIdentity(lat: _location.lat, lng: _location.lng);
    _level = Level.fromPostCount(await _backend.postCount());
    _eventSub = _backend.nearbyEventStream().listen((e) {
      _lastEvent = e;
      _notifications.showEvent(e); // real system notification
      notifyListeners();
    });
    _ready = true;
    notifyListeners();
  }

  Future<void> refreshLevel() async {
    _level = Level.fromPostCount(await _backend.postCount());
    notifyListeners();
  }

  void consumeEvent() => _lastEvent = null;

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
