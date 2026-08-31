import 'package:flutter/widgets.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:go_router/go_router.dart';

/// Shared route actions that must never stack the same tool twice.
abstract final class AppRouteActions {
  /// AI Listing Builder is a replaceable tool, not a pushed stack page.
  /// Profile, the dock sparkle, and empty-gallery add all go here so Back
  /// cannot bounce through leftover listing-builder copies.
  static void openAiListingBuilder(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.state.uri.path == AppPaths.ownerListingsNew) return;
    router.go(AppPaths.ownerListingsNew);
  }
}
