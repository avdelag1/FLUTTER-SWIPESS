import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/core/performance/app_performance_bootstrap.dart';

/// Soft Instagram-style refresh for the dashboard feed only.
abstract final class AppRefreshService {
  static Future<void> refreshDashboard(WidgetRef ref) async {
    final context = ref.context;
    if (!context.mounted) return;
    await refreshDashboardContainer(
      ProviderScope.containerOf(context, listen: false),
    );
  }

  static Future<void> refreshDashboardContainer(
    ProviderContainer container, {
    bool haptic = true,
  }) async {
    final startedAt = DateTime.now();
    if (haptic) AppHaptics.selection();

    const listingCategories = <String>[
      'property',
      'services',
      'yacht',
      'motorcycle',
      'bicycle',
    ];
    const peopleCategories = <String>['buyers', 'renters', 'seekers'];

    container.invalidate(newItemsCountProvider);
    container.invalidate(eventsListProvider);
    container.invalidate(dashboardVideoEventsProvider);
    container.invalidate(swipeListingsProvider);
    for (final category in listingCategories) {
      container.invalidate(quickFilterPreviewListingsProvider(category));
    }
    for (final category in peopleCategories) {
      container.invalidate(quickFilterPeoplePreviewProvider(category));
    }

    await Future.wait<void>([
      _safe(() => container.read(eventsListProvider.notifier).refresh()),
      _safe(() async {
        await container.read(newItemsCountProvider.future);
      }),
      _safe(() async {
        await container.read(dashboardVideoEventsProvider.future);
      }),
      for (final category in listingCategories)
        _safe(() async {
          await container.read(
            quickFilterPreviewListingsProvider(category).future,
          );
        }),
      for (final category in peopleCategories)
        _safe(() async {
          await container.read(
            quickFilterPeoplePreviewProvider(category).future,
          );
        }),
      _safe(() => AppPerformanceBootstrap.warmInteractiveSurfaces(container)),
    ]);

    const minimumVisible = Duration(milliseconds: 420);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minimumVisible) {
      await Future<void>.delayed(minimumVisible - elapsed);
    }
  }

  static Future<void> refreshDashboardSilently(WidgetRef ref) async {
    final context = ref.context;
    if (!context.mounted) return;
    await refreshDashboardContainer(
      ProviderScope.containerOf(context, listen: false),
      haptic: false,
    );
  }

  static Future<void> refreshAll(WidgetRef ref) => refreshDashboard(ref);

  static Future<void> refreshContainer(ProviderContainer container) =>
      refreshDashboardContainer(container);

  static Future<void> _safe(FutureOr<void> Function() run) async {
    try {
      await run();
    } catch (e, st) {
      debugPrint('App refresh step skipped: $e\n$st');
    }
  }
}
