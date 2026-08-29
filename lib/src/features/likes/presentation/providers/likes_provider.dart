import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/likes/data/repositories/likes_repository.dart';
import 'package:flutter_swipes/src/features/likes/domain/profile_like.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    AsyncNotifierProvider.autoDispose<LikedListingsNotifier, List<Listing>>(
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
    AsyncNotifierProvider.autoDispose<LikedPeopleNotifier, List<ProfileLike>>(
      LikedPeopleNotifier.new,
    );

Future<Set<String>> _fetchLikedTargetIds(String targetType) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const <String>{};

  final rows = await client
      .from('likes')
      .select('target_id')
      .eq('user_id', userId)
      .eq('target_type', targetType)
      .eq('direction', 'right');

  return (rows as List)
      .map((row) => (row as Map<String, dynamic>)['target_id']?.toString())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();
}

/// Discovery needs only IDs. Reading the full liked Listing models can fail if
/// one old/saved listing has malformed or legacy columns, which used to make the
/// map fail open and show liked items again. These providers query the canonical
/// `likes` decision rows directly so a right-swipe always stays excluded.
final likedListingIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  // The map save flow already invalidates likedListingsProvider. Watching it
  // here makes the canonical ID set refresh in the same frame, so a saved item
  // cannot reappear after closing/reopening Map.
  ref.watch(likedListingsProvider);
  return _fetchLikedTargetIds('listing');
});

final likedPeopleIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  ref.watch(likedPeopleProvider);
  return _fetchLikedTargetIds('profile');
});

/// Map discovery excludes every target already saved/right-swiped by the user,
/// including events. Likes is the source of truth across all discovery types.
final likedEventIdsProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) => _fetchLikedTargetIds('event'),
);

class InterestedClientsNotifier extends AsyncNotifier<List<InterestedClient>> {
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
