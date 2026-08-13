import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_sync.dart';
import 'src/app.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // WEB BLACK SCREEN FIX:
  // FlutterNativeSplash.preserve() defers the first frame. Our HTML splash can
  // disappear first → pure black until Dart reaches remove(). Never preserve on web.
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  }

  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemDark);
  unawaited(SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));

  // Router/auth touch Supabase.instance — must init before runApp.
  try {
    await SupabaseService.initialize().timeout(const Duration(seconds: 6));
  } catch (e, st) {
    debugPrint('Supabase bootstrap failed/timed out: $e\n$st');
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
