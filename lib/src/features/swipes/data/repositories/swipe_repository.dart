import 'dart:async';

import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records discovery decisions through the server-side state machine.
///
/// Product rules:
/// - right = free interest and removed from discovery
/// - left = pass/cooldown state
/// - communication is opened by a free accepted match or an accepted Direct
///   Request; a swipe itself never consumes a token.
class SwipeRepository {
  final SupabaseClient _client;
  final OfflineSwipeQueue _offlineQueue;

  SwipeRepository({SupabaseClient? client, OfflineSwipeQueue? offlineQueue})
      : _client = client ?? Supabase.instance.client,
        _offlineQueue = offlineQueue ?? OfflineSwipeQueue(client: client);

  Future<({int synced, int failed})> flushOfflineQueue() => _offlineQueue.flush();

  Future<void> _afterSuccessfulWrite() async {
    unawaited(_offlineQueue.flush());
  }

  Future<void> _recordDecision({
    required String targetId,
    required String targetType,
    required String direction,
  }) async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc(
        'rpc_record_discovery_decision',
        params: {
          'p_target_id': targetId,
          'p_target_type': targetType,
          'p_direction': direction,
        },
      );
      await _afterSuccessfulWrite();
    } catch (error) {
      if (!OfflineSwipeQueue.isNetworkFailure(error)) rethrow;
      await _offlineQueue.enqueue(
        targetId: targetId,
        direction: direction,
        targetType: targetType,
      );
    }
  }

  Future<void> likeListing(String targetId) => _recordDecision(
        targetId: targetId,
        targetType: 'listing',
        direction: 'right',
      );

  Future<void> dislikeListing(String targetId) => _recordDecision(
        targetId: targetId,
        targetType: 'listing',
        direction: 'left',
      );

  Future<void> undoSwipe(String targetId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('likes')
        .delete()
        .eq('user_id', userId)
        .eq('target_id', targetId)
        .eq('target_type', 'listing');
  }

  Future<bool> checkForMatch(String targetId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final match = await _client
        .from('matches')
        .select('id')
        .or('client_id.eq.$userId,owner_id.eq.$userId')
        .eq('listing_id', targetId)
        .eq('status', 'active')
        .maybeSingle();
    return match != null;
  }

  Future<void> likeProfile(String targetUserId) => _recordDecision(
        targetId: targetUserId,
        targetType: 'profile',
        direction: 'right',
      );

  Future<void> dislikeProfile(String targetUserId) => _recordDecision(
        targetId: targetUserId,
        targetType: 'profile',
        direction: 'left',
      );

  Future<void> undoProfileSwipe(String targetUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('likes')
        .delete()
        .eq('user_id', userId)
        .eq('target_id', targetUserId)
        .eq('target_type', 'profile');
  }

  /// Compatibility method used by existing accepted-match messaging surfaces.
  ///
  /// It never buys a thread or bypasses consent. The current user may be either
  /// side of the already-open free conversation.
  Future<String?> startConversation({
    required String ownerId,
    String? listingId,
    String initialMessage = 'Hi! I liked your listing on Swipess.',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    var query = _client
        .from('conversations')
        .select('id,client_id,owner_id')
        .or('client_id.eq.$userId,owner_id.eq.$userId')
        .eq('free_messaging', true)
        .neq('status', 'archived');
    if (listingId != null) {
      query = query.eq('listing_id', listingId);
    }

    final rows = await query.order('created_at', ascending: false).limit(50);
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final clientId = row['client_id']?.toString();
      final conversationOwnerId = row['owner_id']?.toString();
      final samePair =
          (clientId == userId && conversationOwnerId == ownerId) ||
          (clientId == ownerId && conversationOwnerId == userId);
      if (samePair) return row['id']?.toString();
    }
    return null;
  }
}
