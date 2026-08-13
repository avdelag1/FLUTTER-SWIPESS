import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/likes/data/repositories/likes_repository.dart';
import 'package:flutter_swipes/src/features/likes/domain/profile_like.dart';
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

  Future<void> remove(String listingId) async {
    final previous = state.value ?? const <Listing>[];
    state = AsyncData(previous.where((l) => l.id != listingId).toList());
    try {
      await ref.read(likesRepositoryProvider).removeLikedListing(listingId);
    } catch (_) {
      state = AsyncData(previous);
    }
  }
}

final likedListingsProvider =
    AsyncNotifierProvider<LikedListingsNotifier, List<Listing>>(
  LikedListingsNotifier.new,
);

class LikedPeopleNotifier extends AsyncNotifier<List<ProfileLike>> {
  @override
  Future<List<ProfileLike>> build() {
    return ref.read(likesRepositoryProvider).fetchLikedPeople();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(likesRepositoryProvider).fetchLikedPeople(),
    );
  }

  Future<void> remove(String userId) async {
    final previous = state.value ?? const <ProfileLike>[];
    state = AsyncData(previous.where((p) => p.userId != userId).toList());
    try {
      await ref.read(likesRepositoryProvider).removeLikedPerson(userId);
    } catch (_) {
      state = AsyncData(previous);
    }
  }
}

final likedPeopleProvider =
    AsyncNotifierProvider<LikedPeopleNotifier, List<ProfileLike>>(
  LikedPeopleNotifier.new,
);

class InterestedClientsNotifier
    extends AsyncNotifier<List<InterestedClient>> {
  @override
  Future<List<InterestedClient>> build() {
    return ref.read(likesRepositoryProvider).fetchInterestedClients();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(likesRepositoryProvider).fetchInterestedClients(),
    );
  }

  Future<void> dismiss(String userId) async {
    final previous = state.value ?? const <InterestedClient>[];
    state = AsyncData(previous.where((c) => c.userId != userId).toList());
    try {
      await ref.read(likesRepositoryProvider).dismissInterestedClient(userId);
    } catch (_) {
      state = AsyncData(previous);
    }
  }
}

final interestedClientsProvider =
    AsyncNotifierProvider<InterestedClientsNotifier, List<InterestedClient>>(
  InterestedClientsNotifier.new,
);
