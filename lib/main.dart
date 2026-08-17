import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/native/system_chrome_service.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/app_splash_screen.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_sync.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'src/app.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  }

  // Configure synchronous platform values first, but never hold the first
  // Flutter frame while waiting for platform channels or local service boot.
  final mapboxToken = AppConfig.mapboxAccessToken.trim();
  if (mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }

  unawaited(SystemChromeService.initialize());
  unawaited(
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _BootstrapApp(container: container),
    ),
  );

  // The native screen and Flutter splash deliberately use the same canvas.
  // Remove the native layer only after Flutter has painted its first frame, so
  // there is no white/blank intermediary frame during a cold start.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!kIsWeb) FlutterNativeSplash.remove();
  });
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp({required this.container});

  final ProviderContainer container;

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  bool _ready = false;
  bool _booting = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_booting || _ready) return;
    _booting = true;
    _attempts += 1;

    try {
      // Supabase.initialize mainly restores the local session. Let the small
      // Flutter splash render while that work happens instead of delaying the
      // entire first frame behind the native launch screen.
      await SupabaseService.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      _scheduleBackgroundWarmup();
    } catch (e, st) {
      debugPrint('Supabase bootstrap failed: $e\n$st');
      _booting = false;

      // A one-time retry handles transient local/plugin startup races without
      // flashing an error page during launch. The visual remains the same
      // simple logo + loader.
      if (mounted && _attempts < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (mounted) unawaited(_bootstrap());
      }
      return;
    }

    _booting = false;
  }

  void _scheduleBackgroundWarmup() {
    // Do not let StoreKit/Play billing setup or offline network reconciliation
    // compete with the first usable app frame. The UI becomes interactive
    // first, then non-critical work starts quietly just after it settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        unawaited(flushOfflineSwipeQueue());
        unawaited(_initializePayments());
      });
    });
  }

  Future<void> _initializePayments() async {
    try {
      String? userId;
      try {
        userId = SupabaseService.client.auth.currentUser?.id;
      } catch (_) {}

      await widget.container
          .read(paymentServiceProvider)
          .init(userId: userId)
          .timeout(const Duration(seconds: 8));
    } catch (e, st) {
      debugPrint('Payment bootstrap skipped: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const NativeSwipeApp();

    // This is intentionally tiny and dependency-free. It paints immediately
    // while the real app restores its local services.
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppSplashScreen(),
    );
  }
}
