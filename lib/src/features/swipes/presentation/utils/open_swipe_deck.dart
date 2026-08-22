import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:go_router/go_router.dart';

/// Opens a real swipe deck only for marketplace/discovery categories.
///
/// Dashboard quick filters that represent full product sections must never be
/// forced through an empty listing deck. They route directly to their section.
Future<T?> openClientSwipeDeck<T extends Object?>(
  BuildContext context, {
  required String categoryId,
  required String categoryTitle,
  bool replace = false,
}) {
  switch (categoryId) {
    case 'legal':
      context.go(AppPaths.clientLegalServices);
      return Future<T?>.value(null);
    case 'premium':
      context.go(AppPaths.subscriptionPackages);
      return Future<T?>.value(null);
    case 'seekers':
      context.go(AppPaths.exploreSeekers);
      return Future<T?>.value(null);
    case 'events':
      context.go(AppPaths.exploreEvents);
      return Future<T?>.value(null);
  }

  final route = MaterialPageRoute<T>(
    builder: (_) => ClientSwipeContainer(
      categoryId: categoryId,
      categoryTitle: categoryTitle,
    ),
  );
  final nav = Navigator.of(context, rootNavigator: true);
  if (replace) return nav.pushReplacement(route);
  return nav.push(route);
}
