import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:go_router/go_router.dart';

/// Opens a real swipe deck only for marketplace/discovery categories.
///
/// Dashboard quick filters that represent full product sections must never be
/// forced through an empty listing deck. They route directly to their section.
///
/// IMPORTANT: this helper is also called from Intel Core, which lives inside a
/// root overlay. Capture the router/navigator first, close the concierge, then
/// navigate with the captured objects. Using the overlay BuildContext after it
/// is dismissed can crash Flutter Web with a null-check error and make an
/// "Open Listings" tap appear to do nothing.
Future<T?> openClientSwipeDeck<T extends Object?>(
  BuildContext context, {
  required String categoryId,
  required String categoryTitle,
  bool replace = false,
}) async {
  final router = GoRouter.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  final container = ProviderScope.containerOf(context, listen: false);

  // Harmless when Intel Core is not open; essential when this action comes
  // from an AI follow-up chip so the destination is not hidden underneath it.
  container.read(overlayModalsProvider.notifier).closeConcierge();

  // Let the overlay leave the tree before pushing the next full-screen deck.
  // We deliberately do not touch the caller BuildContext after this point.
  await Future<void>.delayed(Duration.zero);

  switch (categoryId) {
    case 'legal':
      router.go(AppPaths.clientLegalServices);
      return null;
    case 'premium':
      router.go(AppPaths.subscriptionPackages);
      return null;
    case 'seekers':
      router.go(AppPaths.exploreSeekers);
      return null;
    case 'events':
      router.go(AppPaths.exploreEvents);
      return null;
  }

  if (!nav.mounted) return null;

  final route = MaterialPageRoute<T>(
    builder: (_) => ClientSwipeContainer(
      categoryId: categoryId,
      categoryTitle: categoryTitle,
    ),
  );
  if (replace) return nav.pushReplacement(route);
  return nav.push(route);
}
