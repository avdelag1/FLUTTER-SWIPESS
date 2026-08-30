import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/platform/hard_reload.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_sync.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/core/performance/app_performance_bootstrap.dart';

/// Hard refresh for the dashboard pull gesture — invalidates live data, clears
/// hot caches, re-warms interactive surfaces, then reloads the web shell.
abstract final class AppRefreshService {
  static Future<void> refreshAll(WidgetRef ref) async {
    AppHaptics.heavy();

    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();

    ref.invalidate(newItemsCountProvider);
    ref.invalidate(appMarketProvider);
    ref.invalidate(appSessionProvider);
    ref.invalidate(eventsListProvider);
    ref.invalidate(dashboardVideoEventsProvider);
    ref.invalidate(mapListingsProvider);
    ref.invalidate(mapProfilesProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(vapIdProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(unreadNotificationsProvider);
    ref.invalidate(likedListingIdsProvider);
    ref.invalidate(likedPeopleIdsProvider);
    ref.invalidate(likedEventIdsProvider);
    ref.invalidate(likedListingsProvider);
    ref.invalidate(likedPeopleProvider);
    ref.invalidate(swipeListingsProvider);

    await Future.wait<void>([
      _safe(() => ref.read(subscriptionProvider.notifier).refresh()),
      _safe(() => ref.read(conversationsProvider.notifier).refresh()),
      _safe(() => ref.read(documentsProvider.notifier).refresh()),
      _safe(() => ref.read(likedListingsProvider.notifier).refresh()),
      _safe(() => ref.read(likedPeopleProvider.notifier).refresh()),
      _safe(() => flushOfflineSwipeQueue()),
      _safe(
        () => AppPerformanceBootstrap.warmInteractiveSurfaces(
          ProviderScope.containerOf(ref.context, listen: false),
        ),
      ),
    ]);

    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await hardReloadApp();
    }
  }

  static Future<void> _safe(FutureOr<void> Function() run) async {
    try {
      await run();
    } catch (e, st) {
      debugPrint('App refresh step skipped: $e\n$st');
    }
  }
}
