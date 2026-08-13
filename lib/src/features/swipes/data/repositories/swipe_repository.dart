import 'dart:async';

import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for recording swipe actions (likes / dislikes) to the `likes` table.
///
/// The web app uses a `likes` table with a 2-pass dismiss system:
/// - 1st left swipe → 5-day cooldown
/// - 2nd left swipe → permanent pass
/// - right swipe → liked
///
/// Network write failures are queued locally (Cap `offlineSwipeQueue.ts`) and
/// flushed on app start, resume, and after the next successful swipe path.
class SwipeRepository {
  final SupabaseClient _client;
  final OfflineSwipeQueue _offlineQueue;

  SwipeRepository({
    SupabaseClient? client,
    OfflineSwipeQueue? offlineQueue,
  })  : _client = client ?? Supabase.instance.client,
        _offlineQueue = offlineQueue ?? OfflineSwipeQueue(client: client);

  /// Flush any locally queued swipes (Cap `syncQueuedSwipes`).
  Future<({int synced, int failed})> flushOfflineQueue() =>
      _offlineQueue.flush();

  Future<void> _afterSuccessfulWrite() async {
    // Cap: flush on next successful swipe path.
    unawaited(_offlineQueue.flush());
  }

  Future<void> _queueOnNetworkFailure({
    required Object error,
    required String targetId,
    required String direction,
    required String targetType,
  }) async {
    if (!OfflineSwipeQueue.isNetworkFailure(error)) throw error;
    await _offlineQueue.enqueue(
      targetId: targetId,
      direction: direction,
      targetType: targetType,
    );
  }

  /// Record a right swipe (LIKE) on a listing.
  Future<void> likeListing(String targetId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('likes').upsert({
        'user_id': userId,
        'target_id': targetId,
        'target_type': 'listing',
        'direction': 'right',
        'dismiss_count': 0,
      }, onConflict: 'user_id,target_id,target_type');
      await _afterSuccessfulWrite();
    } catch (e) {
      await _queueOnNetworkFailure(
        error: e,
        targetId: targetId,
        direction: 'right',
        targetType: 'listing',
      );
    }
  }

  /// Record a left swipe (PASS/DISLIKE) on a listing.
  Future<void> dislikeListing(String targetId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Check if there's already a dismiss record
      final existing = await _client
          .from('likes')
          .select('id, dismiss_count')
          .eq('user_id', userId)
          .eq('target_id', targetId)
          .eq('target_type', 'listing')
          .maybeSingle();

      final currentCount = (existing?['dismiss_count'] as int?) ?? 0;
      final newCount = currentCount + 1;

      // 1st dismiss = 5-day cooldown, 2nd+ = permanent pass
      final cooldownUntil = newCount == 1
          ? DateTime.now().add(const Duration(days: 5)).toUtc().toIso8601String()
          : null;

      await _client.from('likes').upsert({
        'user_id': userId,
        'target_id': targetId,
        'target_type': 'listing',
        'direction': 'left',
        'dismiss_count': newCount,
        'dismissed_at': DateTime.now().toUtc().toIso8601String(),
        // ignore: use_null_aware_elements
        if (cooldownUntil != null) 'cooldown_until': cooldownUntil,
      }, onConflict: 'user_id,target_id,target_type');
      await _afterSuccessfulWrite();
    } catch (e) {
      await _queueOnNetworkFailure(
        error: e,
        targetId: targetId,
        direction: 'left',
        targetType: 'listing',
      );
    }
  }

  /// Undo the last swipe on a listing (delete the record).
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

    // The DB trigger `handle_mutual_like()` creates the match automatically.
    // We just check if a match was created for this listing.
    final match = await _client
        .from('matches')
        .select('id')
        .or('client_id.eq.$userId,owner_id.eq.$userId')
        .eq('listing_id', targetId)
        .eq('status', 'active')
        .maybeSingle();

    return match != null;
  }

  /// Record a right swipe (LIKE) on a profile (Cap roommate / client matching).
  Future<void> likeProfile(String targetUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('likes').upsert({
        'user_id': userId,
        'target_id': targetUserId,
        'target_type': 'profile',
        'direction': 'right',
        'dismiss_count': 0,
      }, onConflict: 'user_id,target_id,target_type');
      await _afterSuccessfulWrite();
    } catch (e) {
      await _queueOnNetworkFailure(
        error: e,
        targetId: targetUserId,
        direction: 'right',
        targetType: 'profile',
      );
    }
  }

  /// Record a left swipe (PASS) on a profile.
  Future<void> dislikeProfile(String targetUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final existing = await _client
          .from('likes')
          .select('id, dismiss_count')
          .eq('user_id', userId)
          .eq('target_id', targetUserId)
          .eq('target_type', 'profile')
          .maybeSingle();

      final currentCount = (existing?['dismiss_count'] as int?) ?? 0;
      final newCount = currentCount + 1;
      final cooldownUntil = newCount == 1
          ? DateTime.now().add(const Duration(days: 5)).toUtc().toIso8601String()
          : null;

      await _client.from('likes').upsert({
        'user_id': userId,
        'target_id': targetUserId,
        'target_type': 'profile',
        'direction': 'left',
        'dismiss_count': newCount,
        'dismissed_at': DateTime.now().toUtc().toIso8601String(),
        'cooldown_until': ?cooldownUntil,
      }, onConflict: 'user_id,target_id,target_type');
      await _afterSuccessfulWrite();
    } catch (e) {
      await _queueOnNetworkFailure(
        error: e,
        targetId: targetUserId,
        direction: 'left',
        targetType: 'profile',
      );
    }
  }

  /// Undo the last profile swipe.
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

  /// Open or create a conversation with a listing owner (Capacitor match flow).
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
      // Fall through to direct upsert
    }

    final existing = await _client
        .from('conversations')
        .select('id')
        .eq('client_id', userId)
        .eq('owner_id', ownerId)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final inserted = await _client.from('conversations').insert({
      'client_id': userId,
      'owner_id': ownerId,
      'listing_id': listingId,
      'status': 'active',
      'free_messaging': true,
    }).select('id').single();
    return inserted['id'] as String;
  }
}
