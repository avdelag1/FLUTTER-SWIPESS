import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_queue.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';

/// Cap `initOfflineSync`: flush queued swipes on startup and when the app
/// returns to the foreground (reconnect / visibility proxy).
class OfflineSwipeSyncBootstrap extends StatefulWidget {
  const OfflineSwipeSyncBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineSwipeSyncBootstrap> createState() =>
      _OfflineSwipeSyncBootstrapState();
}

class _OfflineSwipeSyncBootstrapState extends State<OfflineSwipeSyncBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cap: initial sync ~2s after startup.
    unawaited(Future<void>.delayed(const Duration(seconds: 2), _flush));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_flush());
    }
  }

  Future<void> _flush() async {
    try {
      await SwipeRepository().flushOfflineQueue();
    } catch (_) {
      // Best-effort — queue retained for next attempt.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Fire-and-forget flush helper for call sites that already have a queue.
Future<void> flushOfflineSwipeQueue([OfflineSwipeQueue? queue]) async {
  try {
    await (queue ?? OfflineSwipeQueue()).flush();
  } catch (_) {}
}
