import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap parity: `utils/offlineSwipeQueue.ts`
///
/// Persists failed swipe writes to SharedPreferences and syncs them when
/// the device is back online / on app start / after a successful swipe path.
class OfflineSwipeQueue {
  OfflineSwipeQueue({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const queueKey = 'offline-swipe-queue';
  static const maxRetries = 3;

  final SupabaseClient _client;
  Future<({int synced, int failed})>? _flushInFlight;

  /// Whether [error] looks like a network / connectivity failure.
  /// Avoids `dart:io` types so this stays web-safe.
  static bool isNetworkFailure(Object error) {
    if (error is TimeoutException || error is ClientException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('timed out') ||
        text.contains('clientexception') ||
        text.contains('xmlhttprequest') ||
        text.contains('offline');
  }

  Future<List<QueuedSwipe>> getQueuedSwipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(queueKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => QueuedSwipe.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getQueueSize() async => (await getQueuedSwipes()).length;

  /// Queue a swipe for later sync. Duplicates (same target + direction) ignored.
  Future<void> enqueue({
    required String targetId,
    required String direction,
    required String targetType,
  }) async {
    assert(direction == 'left' || direction == 'right');
    assert(targetType == 'listing' || targetType == 'profile');
    try {
      final queue = await getQueuedSwipes();
      final exists = queue.any(
        (q) => q.targetId == targetId && q.direction == direction,
      );
      if (exists) return;

      queue.add(
        QueuedSwipe(
          id: '$targetId-${DateTime.now().millisecondsSinceEpoch}',
          targetId: targetId,
          direction: direction,
          targetType: targetType,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          retryCount: 0,
        ),
      );
      await _persist(queue);
      debugPrint('[OfflineQueue] Swipe queued for sync: $targetId');
    } catch (e) {
      debugPrint('[OfflineQueue] Failed to queue swipe: $e');
    }
  }

  /// Sync all queued swipes. Safe to call concurrently — coalesces in-flight.
  Future<({int synced, int failed})> flush() {
    return _flushInFlight ??= _flushInternal().whenComplete(() {
      _flushInFlight = null;
    });
  }

  Future<({int synced, int failed})> _flushInternal() async {
    final queue = await getQueuedSwipes();
    if (queue.isEmpty) return (synced: 0, failed: 0);

    debugPrint('[OfflineQueue] Syncing ${queue.length} queued swipes');

    var synced = 0;
    var failed = 0;

    for (final swipe in List<QueuedSwipe>.from(queue)) {
      final ok = await _syncSwipe(swipe);
      if (ok) {
        await _remove(swipe.id);
        synced++;
      } else {
        await _markFailed(swipe.id);
        failed++;
      }
    }

    if (synced > 0) {
      debugPrint(
        '[OfflineQueue] Sync complete: $synced synced, $failed failed',
      );
    }
    return (synced: synced, failed: failed);
  }

  Future<bool> _syncSwipe(QueuedSwipe swipe) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[OfflineQueue] No user for sync');
        return false;
      }

      await _client.from('likes').upsert({
        'user_id': userId,
        'target_id': swipe.targetId,
        'target_type': swipe.targetType,
        'direction': swipe.direction,
      }, onConflict: 'user_id,target_id,target_type');

      debugPrint(
        '[OfflineQueue] Synced swipe: ${swipe.targetId} ${swipe.direction}',
      );
      return true;
    } catch (e) {
      debugPrint('[OfflineQueue] Sync failed: ${swipe.targetId} $e');
      return false;
    }
  }

  Future<void> _remove(String id) async {
    try {
      final queue = await getQueuedSwipes();
      await _persist(queue.where((q) => q.id != id).toList());
    } catch (_) {}
  }

  Future<void> _markFailed(String id) async {
    try {
      final updated = (await getQueuedSwipes())
          .map((q) {
            if (q.id != id) return q;
            return q.copyWith(retryCount: q.retryCount + 1);
          })
          .where((q) => q.retryCount < maxRetries)
          .toList();
      await _persist(updated);
    } catch (_) {}
  }

  Future<void> _persist(List<QueuedSwipe> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(queueKey);
    } else {
      await prefs.setString(
        queueKey,
        jsonEncode(queue.map((e) => e.toJson()).toList()),
      );
    }
  }
}

class QueuedSwipe {
  const QueuedSwipe({
    required this.id,
    required this.targetId,
    required this.direction,
    required this.targetType,
    required this.timestamp,
    required this.retryCount,
  });

  final String id;
  final String targetId;
  final String direction;
  final String targetType;
  final int timestamp;
  final int retryCount;

  QueuedSwipe copyWith({int? retryCount}) {
    return QueuedSwipe(
      id: id,
      targetId: targetId,
      direction: direction,
      targetType: targetType,
      timestamp: timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  factory QueuedSwipe.fromJson(Map<String, dynamic> json) {
    return QueuedSwipe(
      id: json['id'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      direction: json['direction'] as String? ?? 'right',
      targetType: json['targetType'] as String? ?? 'listing',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetId': targetId,
        'direction': direction,
        'targetType': targetType,
        'timestamp': timestamp,
        'retryCount': retryCount,
      };
}
