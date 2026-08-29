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
  bool hideChrome = false,
  bool popSwipeDeck = false,
}) {
  final resolved =
      container ??
      (ref != null
          ? ProviderScope.containerOf(context, listen: false)
          : null);

  if (resolved != null) {
    resolved.read(navTabProvider.notifier).set(NavTab.events);
    if (hideChrome) {
      resolved.read(chromeVisibilityProvider.notifier).hide();
    }
  }

  if (popSwipeDeck) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) rootNav.pop();
  }

  GoRouter.of(context).go(AppPaths.exploreEvents);
}
