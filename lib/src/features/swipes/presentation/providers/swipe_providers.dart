import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

// ─── Repositories ──────────────────────────────────────────────────────────────

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  return ListingRepository();
});

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository();
});

// ─── Filter State ──────────────────────────────────────────────────────────────

class SwipeFilterState {
  final String category;
  final double? minPrice;
  final double? maxPrice;
  final int? minBeds;
  final bool? furnished;
  final bool? petFriendly;

  const SwipeFilterState({
    this.category = 'property',
    this.minPrice,
    this.maxPrice,
    this.minBeds,
    this.furnished,
    this.petFriendly,
  });

  SwipeFilterState copyWith({
    String? category,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    bool? furnished,
    bool? petFriendly,
  }) {
    return SwipeFilterState(
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minBeds: minBeds ?? this.minBeds,
      furnished: furnished ?? this.furnished,
      petFriendly: petFriendly ?? this.petFriendly,
    );
  }
}

class SwipeFilterNotifier extends Notifier<SwipeFilterState> {
  @override
  SwipeFilterState build() => const SwipeFilterState();

  void setCategory(String category) => state = state.copyWith(category: category);
  void setPriceRange(double? min, double? max) => state = state.copyWith(minPrice: min, maxPrice: max);
  void setMinBeds(int? beds) => state = state.copyWith(minBeds: beds);
  void setFurnished(bool? val) => state = state.copyWith(furnished: val);
  void setPetFriendly(bool? val) => state = state.copyWith(petFriendly: val);
  void reset() => state = const SwipeFilterState();
}

final swipeFilterProvider = NotifierProvider<SwipeFilterNotifier, SwipeFilterState>(
  SwipeFilterNotifier.new,
);

// ─── Swipe Feed ────────────────────────────────────────────────────────────────

class SwipeFeedNotifier extends AsyncNotifier<List<Listing>> {
  @override
  Future<List<Listing>> build() async {
    final filters = ref.watch(swipeFilterProvider);
    final repo = ref.read(listingRepositoryProvider);
    return repo.fetchSwipeFeed(category: filters.category);
  }

  void removeTop() {
    final current = state.value;
    if (current != null && current.isNotEmpty) {
      state = AsyncValue.data(current.sublist(1));
    }
  }

  /// Re-insert a listing at the top (undo).
  void undoRemove(Listing listing) {
    final current = state.value ?? [];
    state = AsyncValue.data([listing, ...current]);
  }

  /// Reload the feed.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final swipeFeedProvider = AsyncNotifierProvider<SwipeFeedNotifier, List<Listing>>(
  SwipeFeedNotifier.new,
);

// ─── Swipe History (for undo) ──────────────────────────────────────────────────

class SwipeHistoryNotifier extends Notifier<List<Listing>> {
  @override
  List<Listing> build() => [];

  void push(Listing listing) {
    state = [listing, ...state.take(10)]; // Keep last 10
  }

  Listing? pop() {
    if (state.isEmpty) return null;
    final top = state.first;
    state = state.sublist(1);
    return top;
  }
}

final swipeHistoryProvider = NotifierProvider<SwipeHistoryNotifier, List<Listing>>(
  SwipeHistoryNotifier.new,
);
