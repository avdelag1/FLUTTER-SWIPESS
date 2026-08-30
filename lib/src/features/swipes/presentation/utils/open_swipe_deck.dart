import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/events/presentation/utils/open_events_feed.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:go_router/go_router.dart';

/// Opens a real swipe deck only for marketplace/discovery categories.
///
/// Dashboard quick filters that represent full product sections must never be
/// forced through an empty listing deck. They route directly to their section.
///
/// IMPORTANT: this helper is also called from Intel Core, which lives inside a
/// root overlay. Capture the router/navigator first, close the concierge only
/// when it is actually open, then navigate with the captured objects. Normal
/// dashboard taps deliberately avoid an async yield so the destination appears
/// in the same frame and feels immediate in web/PWA/native builds.
Future<T?> openClientSwipeDeck<T extends Object?>(
  BuildContext context, {
  required String categoryId,
  required String categoryTitle,
  bool replace = false,
}) async {
  final router = GoRouter.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  final container = ProviderScope.containerOf(context, listen: false);

  // This function is entered directly from the dashboard tap. Preserve the
  // user's sound choice across the route, but silence the old dashboard player
  // before the destination video starts so there is never overlapping audio.
  if (container.read(deckSoundOnProvider)) unlockDeckMedia();
  pauseQuickFilterVideoPlayback();

  final overlay = container.read(overlayModalsProvider);
  if (overlay.showConcierge) {
    container.read(overlayModalsProvider.notifier).closeConcierge();
    // Only overlay-originated navigation needs a yield so its route can leave
    // the tree. Dashboard quick-filter taps do not wait here.
    await Future<void>.delayed(Duration.zero);
  }

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
      openEventsFeed(context, container: container);
      return null;
  }

  if (!nav.mounted || !context.mounted) return null;

  _warmDeckHeroImages(context, container, categoryId);

  // Keep the previous frame visible under a very short fade instead of using
  // MaterialPageRoute's longer platform transition. This removes the dark/
  // black beat users could see after tapping a dashboard video/card.
  final route = PageRouteBuilder<T>(
    opaque: true,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: const Duration(milliseconds: 80),
    pageBuilder: (_, __, ___) => ClientSwipeContainer(
      categoryId: categoryId,
      categoryTitle: categoryTitle,
    ),
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      );
    },
  );

  if (replace) return nav.pushReplacement(route);
  return nav.push(route);
}

bool _isVideoUrl(String value) {
  final l = value.toLowerCase();
  return l.contains('.mp4') ||
      l.contains('.webm') ||
      l.contains('.mov') ||
      l.contains('/videos/');
}

String? _listingHeroImage(Listing listing) {
  for (final raw in listing.images) {
    final url = raw.trim();
    if (url.isNotEmpty && !_isVideoUrl(url)) return url;
  }
  return listing.images.isNotEmpty ? listing.images.first.trim() : null;
}

void _warmDeckHeroImages(
  BuildContext context,
  ProviderContainer container,
  String categoryId,
) {
  final listings = container.read(swipeListingsProvider(categoryId)).value;
  if (listings == null || listings.isEmpty) return;
  final width = (MediaQuery.sizeOf(context).width * 2).round().clamp(480, 1600);
  final warmCount = math.min(8, listings.length);
  for (var i = 0; i < warmCount; i++) {
    final url = _listingHeroImage(listings[i]);
    if (url == null) continue;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      continue;
    }
    final provider = ResizeImage.resizeIfNeeded(width, null, NetworkImage(url));
    unawaited(precacheImage(provider, context).catchError((_) {}));
  }
}
