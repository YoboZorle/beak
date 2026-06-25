import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Location with **battery-friendly defaults** and a graceful fallback.
///
/// Best practice applied here:
///  * Request "when in use" permission only.
///  * Use a coarse [LocationAccuracy.reduced]/[low] for discovery — we only
///    need ~tens-of-metres precision to rank "2 km vs 5 km", not GPS-grade.
///  * Use a `distanceFilter` so the OS only wakes us when the user actually
///    moves (no continuous polling, far less battery drain).
///  * Never block the UI: if permission is denied or unavailable, fall back
///    to a default coordinate so the app still runs end-to-end.
class LocationService {
  // Default fallback (Lagos) keeps the app fully functional without GPS.
  static const double fallbackLat = 6.5244;
  static const double fallbackLng = 3.3792;

  double _lat = fallbackLat;
  double _lng = fallbackLng;

  double get lat => _lat;
  double get lng => _lng;

  /// One-shot coarse fix used at startup / on shake.
  Future<void> refresh() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return; // keep fallback
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // coarse = battery friendly
          distanceFilter: 50, // metres
        ),
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
    } catch (_) {
      // Stay on fallback; never crash the discovery flow.
    }
  }

  /// A low-power position stream the app can subscribe to in the foreground.
  /// The OS only emits when the user moves >100 m, so it costs almost nothing.
  Stream<Position> watch() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 100,
      ),
    );
  }

  /// Haversine distance in metres (works offline, no plugin dependency).
  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // earth radius (m)
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180.0;
}
