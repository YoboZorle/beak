import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Real device location with a robust permission flow and a graceful fallback.
///
/// On a real device this acquires an actual GPS/network fix and a live
/// position stream, so proximity is computed against the user's true
/// coordinates. If the user denies permission (or location is off) the app
/// still runs against a fallback coordinate, and [permissionGranted] /
/// [hasFix] expose the real state so the UI can prompt.
class LocationService {
  // Anchor (Port Harcourt). Keeps the app fully functional without GPS, and is
  // the demo location the beacon is centred on.
  static const double fallbackLat = 4.862749;
  static const double fallbackLng = 6.958916;

  /// DEMO: pin "my" position to the fixed coordinate above so the beacon and
  /// the people around it are deterministic (simulators report random GPS).
  /// Flip to false to use real device GPS again.
  static const bool useDemoPosition = true;

  double _lat = fallbackLat;
  double _lng = fallbackLng;
  bool _hasFix = useDemoPosition;
  bool _permissionGranted = useDemoPosition;

  double get lat => _lat;
  double get lng => _lng;
  bool get hasFix => _hasFix;
  bool get permissionGranted => _permissionGranted;

  /// Ensures we have permission (requesting it if needed). Returns true if we
  /// may read location. Safe to call repeatedly.
  Future<bool> ensurePermission() async {
    if (useDemoPosition) {
      _permissionGranted = true;
      return true;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _permissionGranted = false;
        return false;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      _permissionGranted = perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      return _permissionGranted;
    } catch (_) {
      _permissionGranted = false;
      return false;
    }
  }

  /// One real fix used at startup / on shake. Tries last-known first (instant),
  /// then a fresh medium-accuracy fix (good enough for proximity ranking).
  Future<void> refresh() async {
    if (useDemoPosition) {
      _apply(fallbackLat, fallbackLng);
      return;
    }
    if (!await ensurePermission()) return; // keep fallback
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _apply(last.latitude, last.longitude);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      _apply(pos.latitude, pos.longitude);
    } catch (_) {
      // Keep whatever we have (last-known or fallback).
    }
  }

  /// Live position stream the app subscribes to in the foreground. The OS only
  /// emits when the user moves >25 m, so it costs almost nothing but keeps
  /// proximity current as the user walks around.
  Stream<Position> watch() {
    if (useDemoPosition) return const Stream<Position>.empty();
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 25,
      ),
    );
  }

  /// Apply a position coming from the stream (keeps lat/lng/hasFix in sync).
  void applyPosition(Position p) => _apply(p.latitude, p.longitude);

  void _apply(double lat, double lng) {
    _lat = lat;
    _lng = lng;
    _hasFix = true;
  }

  /// Haversine distance in metres (offline, no plugin dependency).
  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Destination coordinate `dist` metres from (lat,lng) along `bearing` rad.
  /// Used to anchor nearby people in real space around the user.
  static List<double> destination(
      double lat, double lng, double dist, double bearing) {
    final dLat = (dist * cos(bearing)) / 111320.0;
    final dLng = (dist * sin(bearing)) / (111320.0 * cos(_rad(lat)).abs());
    return [lat + dLat, lng + dLng];
  }

  static double _rad(double deg) => deg * pi / 180.0;
}
