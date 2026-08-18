import 'dart:async';

import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records discovery decisions through the server-side state machine.
///
/// Product rules live in `rpc_record_discovery_decision` so every client uses
/// the same behavior:
/// - right = saved and removed from discovery
/// - first left = hidden for 7 days, then one retry
/// - second left = hidden until an objective target improvement
/// - third left = permanent pass
///
/// Network failures are queued locally and replayed through the same RPC.
class SwipeRepository {
  final SupabaseClient _client;
  final OfflineSwipeQueue _offlineQueue;

  SwipeRepository({SupabaseClient? client, OfflineSwipeQueue? offlineQueue})
    : _client = client ?? Supabase.instance.client,
      _offlineQueue = offlineQueue ?? OfflineSwipeQueue(client: client);

  Future<({int synced, int failed})> flushOfflineQueue() =>
      _offlineQueue.flush();

  Future<void> _afterSuccessfulWrite() async {
    unawaited(_offlineQueue.flush());
  }

  Future<void> _recordDecision({
    required String targetId,
    required String targetType,
    required String direction,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

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

  /// Undo intentionally removes the latest decision entirely.
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

  /// Check if a mutual match exists after liking.
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

  /// Open or create a conversation with a listing owner/profile.
  Future<String?> startConversation({
    required String ownerId,
    String? listingId,
    String initialMessage = 'Hi! I liked your listing on Swipess.',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final data = await _client.rpc(
        'start_conversation_with_message',
        params: {
          'p_other_user_id': ownerId,
          'p_initial_message': initialMessage,
          'p_listing_id': listingId,
        },
      );
      final row = data is List && data.isNotEmpty ? data.first : data;
      if (row is Map && row['conversation_id'] != null) {
        return row['conversation_id'] as String;
      }
    } catch (_) {
      // Fall through to direct upsert.
    }

    final existing = await _client
        .from('conversations')
        .select('id')
        .eq('client_id', userId)
        .eq('owner_id', ownerId)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('conversations')
        .insert({
          'client_id': userId,
          'owner_id': ownerId,
          'listing_id': listingId,
          'status': 'active',
          'free_messaging': true,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }
}
