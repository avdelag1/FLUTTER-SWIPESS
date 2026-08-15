import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';

/// Cap `useOfflineDetection` (`@capacitor/network`).
///
/// Cap deliberately used the native plugin rather than `navigator.onLine`,
/// which lies inside a WebView. `connectivity_plus` is the same idea on
/// Flutter: it reports the interface the device is attached to, and a banner
/// fires only on an actual transition, so a flaky connection cannot spam.
class ConnectivityNotifier extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  bool build() {
    ref.onDispose(() => _sub?.cancel());
    _listen();
    return true;
  }

  Future<void> _listen() async {
    final connectivity = Connectivity();
    try {
      _apply(await connectivity.checkConnectivity(), announce: false);
    } catch (e) {
      debugPrint('[Connectivity] initial status failed: $e');
    }
    _sub = connectivity.onConnectivityChanged.listen(
      (results) => _apply(results, announce: true),
      onError: (Object e) => debugPrint('[Connectivity] stream error: $e'),
    );
  }

  void _apply(List<ConnectivityResult> results, {required bool announce}) {
    final connected =
        results.any((r) => r != ConnectivityResult.none) && results.isNotEmpty;
    if (connected == state) return;
    state = connected;
    if (!announce) return;

    final notifications = ref.read(appNotificationsProvider.notifier);
    if (connected) {
      notifications.info(
        'Back Online! 🌐',
        'Your connection has been restored.',
      );
    } else {
      notifications.error(
        'Connection Lost 📱',
        "You're now offline. Some features may be limited.",
      );
    }
  }
}

/// `true` while the device has a network interface.
final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

/// Mounts the watcher for the lifetime of the app, the way Cap mounted the hook
/// in `AppLayout`.
class ConnectivityWatcher extends ConsumerWidget {
  const ConnectivityWatcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(connectivityProvider);
    return child;
  }
}
