import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/native/system_chrome_service.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'src/app.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await SystemChromeService.initialize();

  try {
    await SupabaseService.initialize();
  } catch (e, st) {
    debugPrint('Supabase bootstrap failed: $e\n$st');
  }

  final container = ProviderContainer();
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NativeSwipeApp(),
    ),
  );

  FlutterNativeSplash.remove();
}
