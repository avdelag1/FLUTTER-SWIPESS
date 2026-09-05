import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/market_swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository(Supabase.instance.client);
});

/// Authenticated discovery follows the active Passport market and the server
/// feature matrix. Recommended remains an aggregate quality mode instead of
/// being silently rewritten to the filter category.
///
/// This is auto-disposed so leaving a swipe surface cannot preserve an old
/// account/feed snapshot in Riverpod memory. Reopening always resolves against
/// the current signed-in user and current server state.
final swipeListingsProvider = FutureProvider.autoDispose
    .family<List<Listing>, String>((ref, category) async {
      // Marketplace results are personal: RLS and prior swipe decisions depend on
      // the signed-in user. Do not keep an anonymous/previous-account response as
      // the first deck shown after a new login.
      final user = ref.watch(currentUserProvider);
      if (user == null) return const <Listing>[];

      // A dashboard tap should feel like the deck was already waiting behind
      // the tile. Keep a completed full-deck request alive briefly even when
      // it was started speculatively by the app-level warmup below. Realtime
      // invalidation still wins immediately, so this never freezes stale rows.
      final keepAlive = ref.keepAlive();
      final ttl = Timer(const Duration(minutes: 2), keepAlive.close);
      ref.onDispose(ttl.cancel);

      final filters = ref.watch(swipeFilterProvider);
      final discovery = ref.watch(discoveryLocationProvider);
      final repository = ref.read(marketSwipeRepositoryProvider);
      final effectiveCategory = category == 'all' ? filters.category : category;

      final listings = await repository.fetch(
        category: effectiveCategory,
        marketCity: discovery.city,
        marketCountry: discovery.country,
        interestType: filters.interestType,
        minPrice: filters.minPrice,
        maxPrice: filters.maxPrice,
        minBeds: filters.minBeds,
        minBaths: filters.minBaths,
        furnished: filters.furnished,
        petFriendly: filters.petFriendly,
        propertyTypes: filters.propertyTypes,
        limit: 24,
      );

      // Keep publication age tied to the immutable listing row. Edits may
      // refresh content via updated_at, but they must never become a new post.
      if (effectiveCategory == 'recommended') return listings;
      final ordered = List<Listing>.from(listings);
      ordered.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return ordered;
    });

/// Lightweight dashboard preview feed. It intentionally avoids full deck
/// filters and asks the server for only a handful of cards per category.
///
/// Auto-dispose is critical here: the dashboard preview is a live surface, not
/// a persistent cache. Once the tile leaves the widget tree, its old rows are
/// discarded instead of becoming "ghost" listings on the next visit/account.
final quickFilterPreviewListingsProvider = FutureProvider.autoDispose
    .family<List<Listing>, String>((ref, category) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return const <Listing>[];
      final discovery = ref.watch(discoveryLocationProvider);
      final repository = ref.read(marketSwipeRepositoryProvider);

      // Watch the user's swiped listings (both likes and dislikes)
      final allSwipedIds = await ref.watch(allSwipedListingIdsProvider.future);

      final listings = await repository.fetch(
        category: category,
        marketCity: discovery.city,
        marketCountry: discovery.country,
        limit:
            8 +
            allSwipedIds.length, // request more to account for filtered items
      );

      // Dashboard previews are chronological: the latest listing created by
      // another account must be the first card shown for that category.
      final ordered = listings
          .where((l) => !allSwipedIds.contains(l.id))
          .toList();
      ordered.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return ordered.take(8).toList();
    });

/// Starts fresh, account-scoped discovery requests as soon as a session is
/// available. Realtime remains the primary update path. A tiny periodic
/// invalidation is a PWA safety net for browsers that suspend/drop realtime
/// while backgrounded: watched dashboard tiles refetch live rows, while
/// unwatched auto-disposed families cost nothing.
final signedInDiscoveryWarmupProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  const deckCategories = <String>[
    'property',
    'services',
    'worker',
    'yacht',
    'motorcycle',
    'bicycle',
    'recommended',
    'all',
  ];
  const previewCategories = <String>[
    'property',
    'services',
    'yacht',
    'motorcycle',
    'bicycle',
  ];

  void invalidateDiscovery() {
    for (final category in deckCategories) {
      ref.invalidate(swipeListingsProvider(category));
    }
    for (final category in previewCategories) {
      ref.invalidate(quickFilterPreviewListingsProvider(category));
    }
  }

  final client = Supabase.instance.client;
  final realtime = client
      .channel('listing-discovery-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'listings',
        callback: (_) => invalidateDiscovery(),
      )
      .subscribe();

  // Realtime should refresh immediately. The 8s fallback is a PWA safety net
  // for browsers that suspend websockets; native iOS/Android keep a live
  // connection and must not refetch the whole market every few seconds.
  Timer? fallbackRefresh;
  if (kIsWeb) {
    fallbackRefresh = Timer.periodic(
      const Duration(seconds: 8),
      (_) => invalidateDiscovery(),
    );
  }

  ref.onDispose(() {
    fallbackRefresh?.cancel();
    unawaited(client.removeChannel(realtime));
  });

  // Prime the main listing decks immediately after the dashboard paints.
  // Two small batches avoid a startup network spike while still making the
  // first quick-filter tap feel effectively instant on a normal connection.
  unawaited(
    Future<void>.delayed(const Duration(milliseconds: 160), () async {
      Future<void> warmBatch(List<String> categories) async {
        await Future.wait<void>(
          categories.map((category) async {
            if (ref.read(currentUserProvider)?.id != user.id) return;
            try {
              await ref
                  .read(swipeListingsProvider(category).future)
                  .timeout(const Duration(seconds: 4));
            } catch (_) {}
          }),
        );
      }

      await warmBatch(const <String>['property', 'worker', 'yacht']);
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await warmBatch(const <String>['motorcycle', 'bicycle', 'services']);
    }).catchError((_) {}),
  );
});

/// Capacitor-aligned client discovery filters.
class SwipeFilter {
  SwipeFilter({
    this.category = 'property',
    this.interestType = 'both',
    this.minPrice,
    this.maxPrice,
    this.priceRangeLabel,
    this.minBeds,
    this.minBaths,
    this.furnished,
    this.petFriendly,
    this.propertyTypes = const [],
    this.city,
    this.radiusKm = 50,
  });

  final String category;

  /// rent | sale | both
  final String interestType;
  final double? minPrice;
  final double? maxPrice;
  final String? priceRangeLabel;
  final int? minBeds;
  final int? minBaths;
  final bool? furnished;
  final bool? petFriendly;
  final List<String> propertyTypes;
  final String? city;
  final double radiusKm;

  SwipeFilter copyWith({
    String? category,
    String? interestType,
    double? minPrice,
    double? maxPrice,
    String? priceRangeLabel,
    int? minBeds,
    int? minBaths,
    bool? furnished,
    bool? petFriendly,
    List<String>? propertyTypes,
    String? city,
    double? radiusKm,
    bool clearPrice = false,
    bool clearBeds = false,
    bool clearBaths = false,
    bool clearCity = false,
  }) {
    return SwipeFilter(
      category: category ?? this.category,
      interestType: interestType ?? this.interestType,
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      priceRangeLabel: clearPrice
          ? null
          : (priceRangeLabel ?? this.priceRangeLabel),
      minBeds: clearBeds ? null : (minBeds ?? this.minBeds),
      minBaths: clearBaths ? null : (minBaths ?? this.minBaths),
      furnished: furnished ?? this.furnished,
      petFriendly: petFriendly ?? this.petFriendly,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      city: clearCity ? null : (city ?? this.city),
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }
}

/// Cap `useClientFilterPreferences` field mapping onto the Flutter `SwipeFilter`
/// the filter sheet already exposes (category, interest, price, beds/baths,
/// furnished/pet-friendly, property types, one city).
extension SwipeFilterPreferencesMapping on SwipeFilter {
  Map<String, dynamic> toPreferencesPayload() {
    final listingTypes = switch (interestType) {
      'sale' => const ['buy'],
      'both' => const ['rent', 'buy'],
      _ => const ['rent'],
    };
    return {
      'interested_in_properties': category == 'property',
      'interested_in_motorcycles': category == 'motorcycle',
      'interested_in_bicycles': category == 'bicycle',
      'interested_in_vehicles': category == 'yacht',
      'preferred_listing_types': listingTypes,
      'price_min': minPrice,
      'price_max': maxPrice,
      'min_bedrooms': minBeds,
      'min_bathrooms': minBaths,
      'furnished_required': furnished ?? false,
      'pet_friendly_required': petFriendly ?? false,
      'property_types': propertyTypes,
      'location_zones': city != null ? [city] : const <String>[],
    };
  }

  /// Merges a persisted `client_filter_preferences` row onto [base], keeping
  /// [base]'s value for any column that's null/missing.
  static SwipeFilter mergeFromPreferencesRow(
    SwipeFilter base,
    Map<String, dynamic> row,
  ) {
    var category = base.category;
    if (row['interested_in_motorcycles'] == true) {
      category = 'motorcycle';
    } else if (row['interested_in_bicycles'] == true) {
      category = 'bicycle';
    } else if (row['interested_in_vehicles'] == true) {
      category = 'yacht';
    } else if (row['interested_in_properties'] == true) {
      category = 'property';
    }

    final listingTypes =
        (row['preferred_listing_types'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final hasRent = listingTypes.contains('rent');
    final hasBuy = listingTypes.contains('buy');
    final interestType = hasRent && hasBuy
        ? 'both'
        : hasBuy
        ? 'sale'
        : (hasRent ? 'rent' : base.interestType);

    final locationZones =
        (row['location_zones'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    return base.copyWith(
      category: category,
      interestType: interestType,
      minPrice: (row['price_min'] as num?)?.toDouble(),
      maxPrice: (row['price_max'] as num?)?.toDouble(),
      minBeds: (row['min_bedrooms'] as num?)?.toInt(),
      minBaths: (row['min_bathrooms'] as num?)?.toInt(),
      furnished: row['furnished_required'] as bool?,
      petFriendly: row['pet_friendly_required'] as bool?,
      propertyTypes:
          (row['property_types'] as List?)?.map((e) => e.toString()).toList() ??
          base.propertyTypes,
      city: locationZones.isNotEmpty ? locationZones.first : base.city,
    );
  }
}

class SwipeFilterNotifier extends Notifier<SwipeFilter> {
  @override
  SwipeFilter build() => SwipeFilter();

  void replace(SwipeFilter next) => state = next;

  void setCategory(String category) =>
      state = state.copyWith(category: category);

  void setInterestType(String type) {
    final mapped = type == 'buy' ? 'sale' : type;
    state = state.copyWith(interestType: mapped);
  }

  void setCity(String? city) => state = state.copyWith(
    city: city,
    clearCity: city == null || city.trim().isEmpty,
  );

  void setRadiusKm(double km) => state = state.copyWith(radiusKm: km);

  void setPriceRange(double? minPrice, double? maxPrice) =>
      state = state.copyWith(minPrice: minPrice, maxPrice: maxPrice);

  void setMinBeds(int? minBeds) =>
      state = state.copyWith(minBeds: minBeds, clearBeds: minBeds == null);

  void setFurnished(bool? furnished) =>
      state = state.copyWith(furnished: furnished);

  void setPetFriendly(bool? petFriendly) =>
      state = state.copyWith(petFriendly: petFriendly);

  void reset() => state = SwipeFilter();
}

final swipeFilterProvider = NotifierProvider<SwipeFilterNotifier, SwipeFilter>(
  SwipeFilterNotifier.new,
);
