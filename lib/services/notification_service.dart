import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'backend_service.dart';

/// Real on-device notifications. While the app is running (foreground or
/// backgrounded), every nearby event — a new beacon, a nearby story, a Beak,
/// or a message — is shown as a genuine system notification.
///
/// Killed-state remote delivery is handled by FCM in Phase 2; this service is
/// the real, working notification surface for Phase 1 and also displays FCM
/// foreground messages in Phase 2.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'beau_nearby';
  static const _channelName = 'Beacon activity';

  bool _ready = false;
  int _id = 0;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );

    // Android 13+ runtime permission + channel.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'New people, stories and Beaks near you.',
        importance: Importance.high,
      ),
    );

    // iOS runtime permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _ready = true;
  }

  Future<void> showEvent(NearbyEvent e) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    await _plugin.show(_id++, e.title, e.body, details);
  }
}
