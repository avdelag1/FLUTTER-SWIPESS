import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/swipes/data/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository(Supabase.instance.client);
});

// A family provider to fetch listings by category
final swipeListingsProvider = FutureProvider.family<List<Listing>, String>((ref, category) async {
  final repository = ref.read(swipeRepositoryProvider);
  return repository.fetchListings(category: category);
});

class SwipeFilter {
  final String category;
  final double? minPrice;
  final double? maxPrice;
  final int? minBeds;
  final bool? furnished;
  final bool? petFriendly;

  SwipeFilter({
    this.category = 'property',
    this.minPrice,
    this.maxPrice,
    this.minBeds,
    this.furnished,
    this.petFriendly,
  });

  SwipeFilter copyWith({
    String? category,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    bool? furnished,
    bool? petFriendly,
  }) {
    return SwipeFilter(
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minBeds: minBeds ?? this.minBeds,
      furnished: furnished ?? this.furnished,
      petFriendly: petFriendly ?? this.petFriendly,
    );
  }
}

class SwipeFilterNotifier extends Notifier<SwipeFilter> {
  @override
  SwipeFilter build() => SwipeFilter();

  void setCategory(String category) => state = state.copyWith(category: category);
  void setPriceRange(double? minPrice, double? maxPrice) => state = state.copyWith(minPrice: minPrice, maxPrice: maxPrice);
  void setMinBeds(int? minBeds) => state = state.copyWith(minBeds: minBeds);
  void setFurnished(bool? furnished) => state = state.copyWith(furnished: furnished);
  void setPetFriendly(bool? petFriendly) => state = state.copyWith(petFriendly: petFriendly);
  void reset() => state = SwipeFilter();
}

final swipeFilterProvider = NotifierProvider<SwipeFilterNotifier, SwipeFilter>(SwipeFilterNotifier.new);

