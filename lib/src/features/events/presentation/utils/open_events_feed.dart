import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:go_router/go_router.dart';

/// Opens the shell-hosted Events feed (not the listing swipe deck).
void openEventsFeed(
  BuildContext context, {
  WidgetRef? ref,
  ProviderContainer? container,
  bool popSwipeDeck = false,
}) {
  final resolved =
      container ??
      (ref != null ? ProviderScope.containerOf(context, listen: false) : null);

  if (resolved != null) {
    resolved.read(navTabProvider.notifier).set(NavTab.events);

    // Events follows the swipe-deck reveal contract: show the real app
    // header + dock immediately, then EventsScreen auto-hides them with its card.
    resolved.read(chromeVisibilityProvider.notifier).show();
  }

  if (popSwipeDeck) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) rootNav.pop();
  }

  GoRouter.of(context).go(AppPaths.exploreEvents);
}
