import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global runtime tuning so photos, map pins, feeds, and dashboard destinations
/// are already warm by the time the user taps them.
abstract final class AppPerformanceBootstrap {
  static bool _configured = false;

  /// Call once at process start before the first heavy image decode.
  static void configureImagePipeline() {
    if (_configured) return;
    _configured = true;

    // Default Flutter cache is conservative. Swipess is photo/video heavy, so
    // keep more decoded bitmaps in RAM to avoid re-fetching during swipes, map
    // trays, and events reels.
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 320;
    cache.maximumSizeBytes = 280 << 20; // 280 MB
  }

  /// Quietly warm the surfaces users open most often right after dashboard boot.
  ///
  /// These providers are intentionally non-autoDispose, so one background read
  /// keeps the fetched deck in the Riverpod container. A later quick-filter tap
  /// can therefore paint its destination immediately instead of waiting for the
  /// first Supabase round-trip after navigation.
  static Future<void> warmInteractiveSurfaces(ProviderContainer container) async {
    configureImagePipeline();

    await Future.wait<void>([
      _safe(() async {
        await GoogleFonts.pendingFonts([
          GoogleFonts.plusJakartaSans(),
        ]);
      }),
      _safe(() => container.read(discoveryLocationProvider)),
      _safe(() => container.read(mapListingsProvider.future)),
      _safe(() => container.read(mapProfilesProvider.future)),
      _safe(() => container.read(eventsListProvider.future)),
      _safe(() => container.read(dashboardVideoEventsProvider.future)),

      // Warm every marketplace quick filter, not only Properties. This is
      // deliberately scheduled after the first usable frame in main.dart so it
      // improves tap latency without delaying app startup.
      _safe(() => container.read(swipeListingsProvider('property').future)),
      _safe(() => container.read(swipeListingsProvider('services').future)),
      _safe(() => container.read(swipeListingsProvider('yacht').future)),
      _safe(() => container.read(swipeListingsProvider('motorcycle').future)),
      _safe(() => container.read(swipeListingsProvider('bicycle').future)),
      _safe(() => container.read(swipeListingsProvider('recommended').future)),

      _safe(() => container.read(likedListingIdsProvider.future)),
    ]);
  }

  static Future<void> _safe(FutureOr<void> Function() run) async {
    try {
      await run();
    } catch (e, st) {
      debugPrint('Perf warmup skipped: $e\n$st');
    }
  }
}
