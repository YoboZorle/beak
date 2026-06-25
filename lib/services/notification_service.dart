import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'backend_service.dart';

/// Real on-device notifications. Every nearby event — a new beacon/post, a
/// Beak, or a message — is shown as a genuine system notification, including
/// while the app is in the foreground (iOS needs the present* flags below, or
/// it silently swallows foreground notifications — which is the bug that made
/// these look "not working").
///
/// Killed-state remote delivery is FCM (Phase 2); this is the real, working
/// surface for Phase 1 and also renders FCM foreground messages in Phase 2.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'beau_nearby';
  static const _channelName = 'Beacon activity';

  bool _ready = false;
  bool _granted = false;
  int _id = 0;

  bool get granted => _granted;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // Show banners even when the app is in the foreground (iOS 10+).
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );

    // Android 13+ runtime permission + high-importance channel (heads-up).
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

    // iOS / macOS runtime permission.
    final iosGranted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;

    _granted = androidGranted && iosGranted;
    _ready = true;
  }

  Future<void> showEvent(NearbyEvent e) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      ),
      // present* true => shows while app is in the foreground on iOS/macOS.
      iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true),
      macOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true),
    );
    await _plugin.show(_id++, e.title, e.body, details);
  }
}
