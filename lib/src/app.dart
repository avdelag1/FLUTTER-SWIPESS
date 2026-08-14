import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/native/app_badge.dart';
import 'package:flutter_swipes/src/core/native/app_lifecycle_service.dart';
import 'package:flutter_swipes/src/core/native/connectivity_service.dart';
import 'package:flutter_swipes/src/core/native/system_chrome_service.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/routing/global_back_dispatcher.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/overlay_modals_host.dart';
import 'package:flutter_swipes/src/features/native/biometric_gate.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_sync.dart';

class NativeSwipeApp extends ConsumerWidget {
  const NativeSwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(paymentAuthSyncProvider);
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    final isLight = ref.watch(isLightThemeProvider);

    return OfflineSwipeSyncBootstrap(
      child: MaterialApp.router(
        title: 'Swipess',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isLight ? ThemeMode.light : ThemeMode.dark,
        // Spelled out instead of `routerConfig:` so the Android Back key runs
        // through our dispatcher (Cap `useGlobalBackButton`) before GoRouter.
        routeInformationProvider: router.routeInformationProvider,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        backButtonDispatcher: ref.watch(globalBackButtonDispatcherProvider),
        debugShowCheckedModeBanner: false,
        locale: Locale(locale.code),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return SystemChromeSync(
            child: ConnectivityWatcher(
              child: AppLifecycleWatcher(
                child: AppBadgeSync(
                  child: BiometricGate(
                    child: OverlayModalsHost(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
