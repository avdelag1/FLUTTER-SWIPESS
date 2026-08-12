import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/likes/data/repositories/likes_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

final likesRepositoryProvider = Provider<LikesRepository>((ref) {
  return LikesRepository();
});

class LikedListingsNotifier extends AsyncNotifier<List<Listing>> {
  @override
  Future<List<Listing>> build() {
    return ref.read(likesRepositoryProvider).fetchLikedListings();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(likesRepositoryProvider).fetchLikedListings(),
    );
  }
}

final likedListingsProvider =
    AsyncNotifierProvider<LikedListingsNotifier, List<Listing>>(
  LikedListingsNotifier.new,
);
