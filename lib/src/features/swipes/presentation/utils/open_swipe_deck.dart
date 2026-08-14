import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';

/// Opens the Cap swipe deck above [DashboardShell] chrome.
///
/// Must use the root navigator — otherwise shell [AppTopBar] + dock stay
/// visible under the deck and chrome appears twice.
Future<T?> openClientSwipeDeck<T extends Object?>(
  BuildContext context, {
  required String categoryId,
  required String categoryTitle,
  bool replace = false,
}) {
  final route = PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => ClientSwipeContainer(
      categoryId: categoryId,
      categoryTitle: categoryTitle,
    ),
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
  final nav = Navigator.of(context, rootNavigator: true);
  if (replace) return nav.pushReplacement(route);
  return nav.push(route);
}
