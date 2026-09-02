import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/market_swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository(Supabase.instance.client);
});

/// Authenticated discovery follows the active Passport market and the server
/// feature matrix. Recommended remains an aggregate quality mode instead of
/// being silently rewritten to the filter category.
final swipeListingsProvider = FutureProvider.family<List<Listing>, String>((
  ref,
  category,
) async {
  // Marketplace results are personal: RLS and prior swipe decisions depend on
  // the signed-in user. Do not keep an anonymous/previous-account response as
  // the first deck shown after a new login.
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <Listing>[];
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
    limit: 40,
  );

  // A real edit is a fresh marketplace signal. Normal category feeds should
  // surface the most recently updated item first, just like a newly refreshed
  // post. Keep Recommended untouched so its quality/personalization ranking is
  // never replaced by simple recency.
  if (effectiveCategory == 'recommended') return listings;
  final ordered = List<Listing>.from(listings);
  ordered.sort((a, b) {
    final aDate = a.updatedAt ?? a.createdAt;
    final bDate = b.updatedAt ?? b.createdAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return ordered;
});

/// Starts fresh, account-scoped discovery requests as soon as a session is
/// available. This removes the empty first-tap race caused by boot-time
/// prewarming before Supabase restored or changed the local session.
final signedInDiscoveryWarmupProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  unawaited(
    Future.wait<void>([
      ref.read(swipeListingsProvider('property').future),
      ref.read(swipeListingsProvider('services').future),
      ref.read(swipeListingsProvider('yacht').future),
      ref.read(swipeListingsProvider('motorcycle').future),
      ref.read(swipeListingsProvider('bicycle').future),
      ref.read(swipeListingsProvider('recommended').future),
    ]).catchError((_) {}),
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
