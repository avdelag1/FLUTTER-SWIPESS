import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/native/local_notifications_service.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';

final localNotificationsProvider = Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});

/// Cap `useReengagementNotifications` — the nudges hang off the native app
/// lifecycle (`App.appStateChange`): schedule them when the app backgrounds,
/// clear them the moment the user is back, since they obviously did return.
class AppLifecycleWatcher extends ConsumerStatefulWidget {
  const AppLifecycleWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleWatcher> createState() =>
      _AppLifecycleWatcherState();
}

class _AppLifecycleWatcherState extends ConsumerState<AppLifecycleWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = ref.read(localNotificationsProvider);
    notifications.onNotificationRoute = _openRoute;
    // The user is here right now, so clear anything still pending.
    notifications.initialize().then((_) => notifications.cancelReengagement());
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
      case AppLifecycleState.paused:
        notifications.scheduleReengagement();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
