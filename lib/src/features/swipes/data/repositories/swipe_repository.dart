import 'dart:async';

import 'package:flutter_swipes/src/features/direct_requests/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records discovery decisions through the server-side state machine.
///
/// Product rules live in `rpc_record_discovery_decision` so every client uses
/// the same behavior:
/// - right = free interest + owner notification
/// - first left = hidden for 7 days, then one retry
/// - second left = hidden until an objective target improvement
/// - third left = permanent pass
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

  /// Owner accepts a free listing interest. This creates a mutual match and
  /// opens chat for both sides without consuming any token.
  Future<String?> acceptListingInterest({
    required String likerId,
    required String listingId,
  }) async {
    final raw = await _client.rpc(
      'rpc_accept_listing_interest',
      params: {'p_liker_id': likerId, 'p_listing_id': listingId},
    );
    final data = raw is List && raw.isNotEmpty ? raw.first : raw;
    if (data is Map && data['conversation_id'] != null) {
      return data['conversation_id'].toString();
    }
    return null;
  }

  /// Sends a priority Direct Request. The backend reserves one available token
  /// now and only consumes it if the receiver accepts.
  Future<DirectRequestResult> sendDirectRequest({
    required String receiverId,
    String? listingId,
    String message = '',
  }) {
    return DirectRequestRepository(client: _client).send(
      receiverId: receiverId,
      listingId: listingId,
      message: message,
    );
  }

  /// Opens an existing/matched conversation. New cold conversations are never
  /// created here; the server requires mutual consent or an accepted Direct Request.
  Future<String?> startConversation({
    required String ownerId,
    String? listingId,
    String initialMessage = 'Hi! I liked your listing on Swipess.',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

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
      return row['conversation_id'].toString();
    }
    return null;
  }
}
