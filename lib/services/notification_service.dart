import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'backend_service.dart';

/// Real on-device notifications.
///
/// Two kinds, both genuine OS notifications:
///  * **Live** — [showEvent] fires immediately for in-app events (new beacon,
///    Beak, message), shown even while the app is foregrounded (the iOS
///    present* flags below are what make foreground banners appear).
///  * **Scheduled** — [scheduleNearbyTeasers] registers notifications with the
///    OS that fire over the next few minutes **even if the app is backgrounded
///    or closed**, so activity reaches the device, not just the app.
///
/// Server-pushed delivery to a fully killed app (with no prior schedule) is
/// FCM territory (Phase 2); this service also renders FCM foreground messages.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'beau_nearby';
  static const _channelName = 'Beacon activity';
  static const _teaserBase = 7000; // id range for scheduled teasers

  final _rng = Random();
  bool _ready = false;
  bool _granted = false;
  int _id = 0;

  bool get granted => _granted;

  Future<void> init() async {
    if (_ready) return;

    // Timezone DB for scheduling.
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await androidImpl?.requestNotificationsPermission() ?? true;
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'New people, posts and Beaks near you.',
        importance: Importance.max,
      ),
    );

    final iosGranted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;

    _granted = androidGranted && iosGranted;
    _ready = true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
        macOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
      );

  Future<void> showEvent(NearbyEvent e) async {
    if (!_ready) return;
    await _plugin.show(_id++, e.title, e.body, _details);
  }

  /// Schedule a few "activity near you" notifications across the next few
  /// minutes. These are registered with the OS, so they fire on the device
  /// even if the app is closed — e.g. right after you post and lock your screen.
  Future<void> scheduleNearbyTeasers() async {
    if (!_ready) return;
    await cancelNearbyTeasers();

    const teasers = [
      ('📡 New beacon near you', 'Someone just lit up close by — open Beau to see.'),
      ('Someone reacted nearby', 'A beacon near you is getting attention.'),
      ('New story near you', 'A fresh post just dropped on your radar.'),
      ('People are active near you', 'Tap to see who is around right now.'),
    ];

    // Spread across the post lifetime (≈ first ~4 minutes).
    const offsetsSeconds = [25, 70, 150, 235];
    for (var i = 0; i < offsetsSeconds.length; i++) {
      final when =
          tz.TZDateTime.now(tz.local).add(Duration(seconds: offsetsSeconds[i]));
      final t = teasers[i % teasers.length];
      try {
        await _plugin.zonedSchedule(
          _teaserBase + i,
          t.$1,
          t.$2,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Scheduling unavailable on this platform/config — ignore gracefully.
      }
    }
  }

  Future<void> cancelNearbyTeasers() async {
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(_teaserBase + i);
    }
  }
}
