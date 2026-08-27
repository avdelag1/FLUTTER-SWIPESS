import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
import 'package:flutter_swipes/src/core/widgets/swipess_scroll_behavior.dart';
import 'package:flutter_swipes/src/features/gamification/presentation/providers/session_gamification_provider.dart';
import 'package:flutter_swipes/src/features/native/biometric_gate.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_sync.dart';
import 'package:go_router/go_router.dart';

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
        routeInformationProvider: router.routeInformationProvider,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        backButtonDispatcher: ref.watch(globalBackButtonDispatcherProvider),
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SwipessScrollBehavior(),
        locale: Locale(locale.code),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          // MaterialApp.router's builder sits above the Router/Navigator child.
          // Our global modal host also lives here, so without this inherited
          // router, overlay content (notably the Map) cannot use context.push()
          // and throws "No GoRouter found in context" on preview taps.
          return InheritedGoRouter(
            goRouter: router,
            child: _EngagementTrackingBootstrap(
              child: SystemChromeSync(
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
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Keeps engagement tracking alive across every route and reports actual
/// interaction to the reward service. Foreground presence alone is not enough.
class _EngagementTrackingBootstrap extends ConsumerStatefulWidget {
  const _EngagementTrackingBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_EngagementTrackingBootstrap> createState() =>
      _EngagementTrackingBootstrapState();
}

class _EngagementTrackingBootstrapState
    extends ConsumerState<_EngagementTrackingBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sessionGamificationProvider).startTracking(context);
    });
  }

  void _markActivity() {
    ref.read(sessionGamificationProvider).markActivity();
  }

  @override
  void dispose() {
    ref.read(sessionGamificationProvider).stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markActivity(),
      onPointerMove: (_) => _markActivity(),
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) _markActivity();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _markActivity();
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
