import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart'
    as cap;
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deck-facing swipe repository (feed helpers + write facade).
/// Writes delegate to the authoritative discovery-decision repository so the
/// UI never maintains a second like/dislike state machine.
class SwipeRepository {
  SwipeRepository(this._supabase, {cap.SwipeRepository? swipeRepository})
    : _swipes = swipeRepository ?? cap.SwipeRepository(client: _supabase);

  final SupabaseClient _supabase;
  final cap.SwipeRepository _swipes;

  Future<List<Listing>> fetchListings({
    required String category,
    int limit = 10,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        var query = _supabase.from('listings').select('*').eq('is_active', true);
        if (category != 'all' && category != 'recommended' && category != 'popular') {
          query = query.eq('category', category);
        }
        final response = await query.order('created_at', ascending: false).limit(limit);
        return (response as List).map((row) => Listing.fromJson(row)).toList();
      }

      final response = await _supabase.rpc('get_swipe_feed', params: {
        'p_user_id': user.id,
        'p_category': category,
        'p_limit': limit,
      });
      return (response as List).map((row) => Listing.fromJson(row)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> registerSwipeRight(String userId, String listingId) async {
    assert(userId.isNotEmpty);
    await _swipes.likeListing(listingId);
  }

  Future<void> registerSwipeLeft(String userId, String listingId, [num? currentPrice]) async {
    assert(userId.isNotEmpty);
    await _swipes.dislikeListing(listingId);
  }

  Future<void> undoSwipe(String listingId) => _swipes.undoSwipe(listingId);

  Future<({int synced, int failed})> flushOfflineQueue() =>
      _swipes.flushOfflineQueue();

  Future<String?> startConversation({
    required String ownerId,
    required String listingId,
  }) {
    return _swipes.startConversation(ownerId: ownerId, listingId: listingId);
  }

  Future<bool> checkForMatch(String listingId) {
    return _swipes.checkForMatch(listingId);
  }

  Future<void> reportListing({
    required String? reporterId,
    required String listingId,
    required String ownerId,
    required String type,
    required String details,
  }) async {
    try {
      await _supabase.from('reports').insert({
        'reporter_id': reporterId,
        'reported_listing_id': listingId,
        'reported_user_id': ownerId,
        'report_type': type,
        'report_category': 'listing',
        'description': details,
        'status': 'open',
      });
    } catch (_) {
      // Best-effort — still thank the user like the native path.
    }
  }
}
