import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/diagnostics/interaction_diagnostics.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/native/app_badge.dart';
import 'package:flutter_swipes/src/core/native/app_lifecycle_service.dart';
import 'package:flutter_swipes/src/core/native/connectivity_service.dart';
import 'package:flutter_swipes/src/core/native/system_chrome_service.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_navigation_history.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/routing/global_back_dispatcher.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/overlay_modals_host.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_scroll_behavior.dart';
import 'package:flutter_swipes/src/features/gamification/presentation/providers/session_gamification_provider.dart';
import 'package:flutter_swipes/src/features/native/biometric_gate.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_sync.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';

class NativeSwipeApp extends ConsumerWidget {
  const NativeSwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(paymentAuthSyncProvider);
    ref.watch(signedInDiscoveryWarmupProvider);
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    final isLight = ref.watch(isLightThemeProvider);

    // Supabase is ready by the time NativeSwipeApp is mounted, so runtime
    // failures can now be captured without touching first-frame boot time.
    AppInteractionDiagnostics.installErrorHooks();

    return NavigationHistoryBootstrap(
      router: router,
      child: OfflineSwipeSyncBootstrap(
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
            return InteractionDiagnosticsProbe(
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
      ),
    );
  }
}

/// Keeps reward residency tracking alive across every route. The service uses
/// Flutter lifecycle state as the source of truth: foreground time counts,
/// background/hidden/inactive time does not. No pointer or scroll activity is
/// required, so reading and passive video watching continue to earn time.
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

  @override
  void dispose() {
    ref.read(sessionGamificationProvider).stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
