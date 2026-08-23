import 'dart:async';

import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records discovery decisions through the server-side state machine.
///
/// Marketplace communication rules:
/// - right = free interest
/// - left = pass/discovery feedback
/// - mutual/owner-accepted interest = free chat
/// - Direct Request = priority path; one token is reserved and consumed only
///   when the receiver accepts it.
class SwipeRepository {
  final SupabaseClient _client;
  final OfflineSwipeQueue _offlineQueue;
  late final DirectRequestRepository _directRequests = DirectRequestRepository(
    client: _client,
  );

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

  /// Opens/sends into a conversation only when consent exists. For the legacy
  /// owner "Interested Clients" surface, tapping reply is itself an explicit
  /// acceptance of that person's latest listing interest and creates a free
  /// match first. New clients intentionally call the v2 RPC so the rollout
  /// compatibility RPC used by older installed builds cannot bypass consent.
  Future<String?> startConversation({
    required String ownerId,
    String? listingId,
    String initialMessage = 'Hi! I liked your listing on Swipess.',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    if (listingId == null) {
      try {
        final accepted = await _client.rpc(
          'rpc_accept_latest_listing_interest',
          params: {'p_liker_id': ownerId},
        );
        if (accepted is Map && accepted['conversation_id'] != null) {
          return accepted['conversation_id'].toString();
        }
      } catch (_) {
        // Not an owner replying to listing interest; normal match-only gate below.
      }
    }

    final data = await _client.rpc(
      'start_mutual_conversation_v2',
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

  Future<DirectRequestBalance> directRequestBalance() =>
      _directRequests.fetchBalance();

  Future<DirectRequestResult> sendDirectRequest({
    required String receiverId,
    String? listingId,
    String message = '',
  }) => _directRequests.create(
    receiverId: receiverId,
    listingId: listingId,
    message: message,
  );

  Future<DirectRequestResult> respondToDirectRequest({
    required String requestId,
    required bool accept,
  }) => _directRequests.respond(requestId: requestId, accept: accept);

  Future<DirectRequestResult> cancelDirectRequest(String requestId) =>
      _directRequests.cancel(requestId);

  Future<String?> acceptListingInterest({
    required String likerId,
    required String listingId,
  }) => _directRequests.acceptListingInterest(
    likerId: likerId,
    listingId: listingId,
  );
}
