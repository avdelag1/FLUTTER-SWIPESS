import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/events/presentation/utils/open_events_feed.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart';
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
  String? preferredListingId,
  bool replace = false,
}) async {
  final router = GoRouter.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  final container = ProviderScope.containerOf(context, listen: false);
  final me = container.read(currentUserProvider)?.id;

  // This function is entered directly from the dashboard tap. Preserve the
  // user's sound choice across the route and unlock web audio in the same
  // gesture before the destination player starts.
  final soundOn = container.read(deckSoundOnProvider);
  unlockDeckMedia();
  if (soundOn) {
    container.read(deckSoundOnProvider.notifier).preserveAudibleHandoff();
  }

  final handoff = captureQuickFilterVideoForDeck(categoryId: categoryId);
  if (handoff != null) {
    SwipeDeckMediaHandoff.set(handoff);
  } else {
    pauseQuickFilterVideoPlayback();
  }

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

  // Paint the deck from warmed cache on the first frame after the tap.
  // Also capture the exact dashboard preview object synchronously. The light
  // preview feed is intentionally broader than a user's full deck filters, so
  // an ID-only handoff could otherwise fall back to card #1 when the tapped
  // item is outside an active price/rent/sale filter.
  Listing? exactPreviewListing;
  String? safeInitialListingId = preferredListingId?.trim();
  final exactId = safeInitialListingId;
  if (exactId != null && exactId.isNotEmpty) {
    final preview = container
        .read(quickFilterPreviewListingsProvider(categoryId))
        .value;
    if (preview != null) {
      for (final listing in preview) {
        if (listing.id == exactId) {
          exactPreviewListing = listing;
          break;
        }
      }
    }
  }

  // Dashboard quick filters intentionally include the signed-in user's own
  // listings so owners can see how their cards look. The swipe deck is
  // discovery, though, and must NEVER swipe the user's own inventory. The old
  // exact-card handoff reinserted an own preview listing even though the server
  // correctly excluded it from app_get_smart_listings(limit: 24).
  //
  // Drop both the object handoff and the media-controller handoff for that case
  // so the full deck starts on the first eligible listing from another owner.
  if (me != null &&
      exactPreviewListing != null &&
      exactPreviewListing!.ownerId == me) {
    exactPreviewListing = null;
    safeInitialListingId = null;
    SwipeDeckMediaHandoff.clear();
    pauseQuickFilterVideoPlayback();
  }

  unawaited(container.read(swipeListingsProvider(categoryId).future));
  _warmDeckHeroImages(context, container, categoryId);

  final route = PageRouteBuilder<T>(
    opaque: true,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => ClientSwipeContainer(
      categoryId: categoryId,
      categoryTitle: categoryTitle,
      initialListingId: safeInitialListingId,
      initialListing: exactPreviewListing,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );

  if (replace) return nav.pushReplacement(route);
  return nav.push(route);
}

bool _isVideoUrl(String value) {
  final l = value.toLowerCase();
  return l.contains('.mp4') ||
      l.contains('.webm') ||
      l.contains('.mov') ||
      l.contains('.m4v') ||
      l.contains('/videos/');
}

String? _listingHeroImage(Listing listing) {
  final explicitVideo = listing.videoUrl?.trim();
  for (final raw in listing.images) {
    final url = raw.trim();
    if (url.isEmpty || url == explicitVideo || _isVideoUrl(url)) continue;
    return url;
  }
  return null;
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
