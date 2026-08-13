import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart'
    as cap;
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deck-facing swipe repository (feed helpers + write facade).
///
/// Writes delegate to Cap-aligned [cap.SwipeRepository] so offline queueing
/// stays behind the repository layer (no Supabase from UI).
class SwipeRepository {
  SwipeRepository(this._supabase, {cap.SwipeRepository? swipeRepository})
      : _swipes = swipeRepository ?? cap.SwipeRepository(client: _supabase);

  final SupabaseClient _supabase;
  final cap.SwipeRepository _swipes;

  /// Fetch listings for a specific category
  Future<List<Listing>> fetchListings({
    required String category,
    int limit = 10,
  }) async {
    try {
      var query = _supabase.from('listings').select('*').eq('is_active', true);

      // Filter by category unless 'all' or specific bento items like 'recommended'
      if (category != 'all' &&
          category != 'recommended' &&
          category != 'popular') {
        query = query.eq('category', category);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List).map((row) => Listing.fromJson(row)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Register a right swipe (like) — Cap `likes` table + offline queue.
  Future<void> registerSwipeRight(String userId, String listingId) async {
    // userId kept for call-site compatibility; auth user comes from Cap repo.
    assert(userId.isNotEmpty);
    await _swipes.likeListing(listingId);
  }

  /// Register a left swipe (pass) — Cap `likes` table + offline queue.
  Future<void> registerSwipeLeft(String userId, String listingId) async {
    assert(userId.isNotEmpty);
    await _swipes.dislikeListing(listingId);
  }

  Future<({int synced, int failed})> flushOfflineQueue() =>
      _swipes.flushOfflineQueue();
}
