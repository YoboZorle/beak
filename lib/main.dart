import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/beacon_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/session_provider.dart';
import 'services/backend_service.dart';
import 'services/location_service.dart';
import 'services/mock_backend_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Composition root -------------------------------------------------
  final storage = StorageService();
  await storage.init();

  final location = LocationService();

  final notifications = NotificationService();
  await notifications.init();

  // PHASE 1: mock backend. PHASE 2: replace this single line with
  //   final BackendService backend = FirebaseBackendService(storage);
  // Everything above this layer stays identical.
  final BackendService backend = MockBackendService(storage);

  runApp(
    MultiProvider(
      providers: [
        Provider<BackendService>.value(value: backend),
        Provider<StorageService>.value(value: storage),
        Provider<LocationService>.value(value: location),
        Provider<NotificationService>.value(value: notifications),
        ChangeNotifierProvider(
            create: (_) => SessionProvider(backend, location, notifications)),
        ChangeNotifierProvider(
            create: (_) => BeaconProvider(backend, location)),
        ChangeNotifierProvider(create: (_) => ChatProvider(backend)),
      ],
      child: const BeauApp(),
    ),
  );
}
