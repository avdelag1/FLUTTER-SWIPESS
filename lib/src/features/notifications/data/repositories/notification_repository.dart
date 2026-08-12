import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/notifications/domain/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

class NotificationRepository {
  NotificationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AppNotification>> fetchMine() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final data = await _client
        .from('notifications')
        .select(
          'id, notification_type, message, is_read, created_at, title, link_url, related_user_id, metadata',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return (data as List)
        .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> dismiss(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<int> unreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (data as List).length;
  }
}
