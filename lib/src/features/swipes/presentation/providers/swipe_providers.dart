import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository(Supabase.instance.client);
});

/// Family provider to fetch listings by category — respects active Cap filters.
final swipeListingsProvider =
    FutureProvider.family<List<Listing>, String>((ref, category) async {
  final filters = ref.watch(swipeFilterProvider);
  final repository = ref.read(listingRepositoryProvider);
  final effectiveCategory =
      (category == 'all' || category == 'recommended' || category == 'popular')
          ? filters.category
          : category;

  return repository.fetchSwipeFeed(
    category: effectiveCategory,
    interestType: filters.interestType,
    minPrice: filters.minPrice,
    maxPrice: filters.maxPrice,
    minBeds: filters.minBeds,
    minBaths: filters.minBaths,
    furnished: filters.furnished,
    petFriendly: filters.petFriendly,
    propertyTypes: filters.propertyTypes,
    city: filters.city,
    limit: 40,
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
      priceRangeLabel:
          clearPrice ? null : (priceRangeLabel ?? this.priceRangeLabel),
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

class SwipeFilterNotifier extends Notifier<SwipeFilter> {
  @override
  SwipeFilter build() => SwipeFilter();

  void replace(SwipeFilter next) => state = next;

  void setCategory(String category) =>
      state = state.copyWith(category: category);

  void setPriceRange(double? minPrice, double? maxPrice) =>
      state = state.copyWith(minPrice: minPrice, maxPrice: maxPrice);

  void setMinBeds(int? minBeds) => state = state.copyWith(
        minBeds: minBeds,
        clearBeds: minBeds == null,
      );

  void setFurnished(bool? furnished) =>
      state = state.copyWith(furnished: furnished);

  void setPetFriendly(bool? petFriendly) =>
      state = state.copyWith(petFriendly: petFriendly);

  void reset() => state = SwipeFilter();
}

final swipeFilterProvider =
    NotifierProvider<SwipeFilterNotifier, SwipeFilter>(SwipeFilterNotifier.new);
