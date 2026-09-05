import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/native/local_notifications_service.dart';
import 'package:flutter_swipes/src/core/performance/app_refresh_service.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/services/app_playback_hub.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/data/profile_gps_service.dart';

final localNotificationsProvider = Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});

/// Cap `useReengagementNotifications` — the nudges hang off the app lifecycle:
/// schedule them when the app backgrounds/hides and clear them the moment the
/// user is back, since they obviously did return.
class AppLifecycleWatcher extends ConsumerStatefulWidget {
  const AppLifecycleWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleWatcher> createState() =>
      _AppLifecycleWatcherState();
}

class _AppLifecycleWatcherState extends ConsumerState<AppLifecycleWatcher>
    with WidgetsBindingObserver {
  DateTime? _lastContentRefresh;

  void _refreshContentIfStale() {
    final now = DateTime.now();
    final previous = _lastContentRefresh;
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 20)) {
      return;
    }
    _lastContentRefresh = now;
    unawaited(AppRefreshService.refreshDashboardSilently(ref));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = ref.read(localNotificationsProvider);
    notifications.onNotificationRoute = _openRoute;
    // The user is here right now, so clear anything still pending.
    notifications.initialize().then((_) => notifications.cancelReengagement());
  }

  /// `main` deliberately keeps going when the Supabase bootstrap fails, so
  /// asking for the session can throw. A resume must not blow up over it.
  String? _currentUserId() {
    try {
      return ref.read(currentUserProvider)?.id;
    } catch (_) {
      return null;
    }
  }

  void _refreshGps({required bool force}) {
    final userId = _currentUserId();
    if (userId == null) return;
    ref.read(profileGpsServiceProvider).refresh(userId: userId, force: force);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _openRoute(String route) {
    if (!mounted) return;
    ref.read(appRouterProvider).go(route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifications = ref.read(localNotificationsProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        notifications.cancelReengagement();
        // Cap refreshed the phone position on every resume, throttled to one
        // full read every two minutes.
        _refreshGps(force: false);
        _refreshContentIfStale();
        AppPlaybackHub.instance.resumeFromBackground();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // iOS/Android commonly report paused; browsers/PWAs commonly report
        // hidden. Neither path is allowed to request permission here.
        AppPlaybackHub.instance.pauseForBackground();
        pauseQuickFilterVideoPlayback();
        notifications.scheduleReengagement();
      case AppLifecycleState.inactive:
        // Lock-screen / incoming-call snapshot. Pause audible media now so a
        // soundtrack cannot keep running under the system UI.
        AppPlaybackHub.instance.pauseForBackground();
        pauseQuickFilterVideoPlayback();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Signing in is Cap's forced refresh; signing out drops the throttle so the
    // next account does not inherit it.
    ref.listen(currentUserProvider, (previous, next) {
      if (next?.id == previous?.id) return;
      if (next == null) {
        ref.read(profileGpsServiceProvider).reset();
      } else {
        _refreshGps(force: true);
        _lastContentRefresh = null;
        _refreshContentIfStale();
      }
    }, onError: (_, _) {});
    return widget.child;
  }
}
