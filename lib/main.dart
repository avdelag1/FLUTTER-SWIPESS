import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/native/system_chrome_service.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_sync.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'src/app.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  }

  // The map must use the official Mapbox renderer, not only Mapbox raster tiles.
  // The public token stays outside source control and is supplied by --dart-define.
  final mapboxToken = AppConfig.mapboxAccessToken.trim();
  if (mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }

  await SystemChromeService.initialize();
  unawaited(
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  try {
    await SupabaseService.initialize().timeout(const Duration(seconds: 6));
  } catch (e, st) {
    debugPrint('Supabase bootstrap failed/timed out: $e\n$st');
    rethrow;
  }

  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NativeSwipeApp(),
    ),
  );

  if (!kIsWeb) {
    FlutterNativeSplash.remove();
  }

  unawaited(flushOfflineSwipeQueue());

  try {
    String? userId;
    try {
      userId = SupabaseService.client.auth.currentUser?.id;
    } catch (_) {}
    await container
        .read(paymentServiceProvider)
        .init(userId: userId)
        .timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('Payment bootstrap skipped: $e\n$st');
  }
}
