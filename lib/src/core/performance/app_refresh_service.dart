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
    final context = ref.context;
    if (!context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    await refreshContainer(container);
  }

  static Future<void> refreshContainer(ProviderContainer container) async {
    AppHaptics.heavy();

    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();

    container.invalidate(newItemsCountProvider);
    container.invalidate(appMarketProvider);
    container.invalidate(appSessionProvider);
    container.invalidate(eventsListProvider);
    container.invalidate(dashboardVideoEventsProvider);
    container.invalidate(mapListingsProvider);
    container.invalidate(mapProfilesProvider);
    container.invalidate(currentProfileProvider);
    container.invalidate(vapIdProvider);
    container.invalidate(documentsProvider);
    container.invalidate(conversationsProvider);
    container.invalidate(unreadNotificationsProvider);
    container.invalidate(likedListingIdsProvider);
    container.invalidate(likedPeopleIdsProvider);
    container.invalidate(likedEventIdsProvider);
    container.invalidate(likedListingsProvider);
    container.invalidate(likedPeopleProvider);
    container.invalidate(swipeListingsProvider);

    // Web reload tears down the widget tree — never touch a WidgetRef after this
    // point. Invalidate caches, give the elastic pull UI a beat, then reload.
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await hardReloadApp();
      return;
    }

    await Future.wait<void>([
      _safe(() => container.read(subscriptionProvider.notifier).refresh()),
      _safe(() => container.read(conversationsProvider.notifier).refresh()),
      _safe(() => container.read(documentsProvider.notifier).refresh()),
      _safe(() => container.read(likedListingsProvider.notifier).refresh()),
      _safe(() => container.read(likedPeopleProvider.notifier).refresh()),
      _safe(() => flushOfflineSwipeQueue()),
      _safe(() => AppPerformanceBootstrap.warmInteractiveSurfaces(container)),
    ]);
  }

  static Future<void> _safe(FutureOr<void> Function() run) async {
    try {
      await run();
    } catch (e, st) {
      debugPrint('App refresh step skipped: $e\n$st');
    }
  }
}
