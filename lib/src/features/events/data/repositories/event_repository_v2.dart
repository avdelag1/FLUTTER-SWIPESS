import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

/// Event reads retry once after refreshing an authenticated Supabase session.
/// This prevents a recoverable browser 401/403 from collapsing the dashboard
/// video teaser into a static fallback image.
class EventRepository {
  EventRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _full =
      'id, title, description, category, image_url, image_urls, video_url, video_audio_enabled, background_music_url, event_date, event_end_date, location, location_detail, organizer_name, organizer_photo_url, organizer_whatsapp, promo_text, discount_tag, is_free, price_text, created_at';
  static const _withAudio =
      'id, title, description, category, image_url, image_urls, video_url, video_audio_enabled, background_music_url, event_date, location, location_detail, organizer_name, organizer_whatsapp, promo_text, discount_tag, is_free, price_text, created_at';
  static const _base =
      'id, title, description, category, image_url, image_urls, video_url, event_date, location, location_detail, organizer_name, organizer_whatsapp, promo_text, discount_tag, is_free, price_text, created_at';
  static const _legacy =
      'id, title, description, category, image_url, event_date, location, location_detail, organizer_name, organizer_whatsapp, is_free, price_text, promo_text, discount_tag';

  final eventRepositoryProviderFallbackSelects = const [
    _full,
    _withAudio,
    _base,
    _legacy,
  ];

  Future<T> _withSessionRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException {
      if (_client.auth.currentUser == null) rethrow;
      try {
        await _client.auth.refreshSession();
      } catch (_) {
        rethrow;
      }
      return action();
    }
  }

  Future<List<Event>> fetchEvents() async {
    for (final select in eventRepositoryProviderFallbackSelects) {
      try {
        final data = await _withSessionRetry(
          () => _client
              .from('events')
              .select(select)
              .eq('is_published', true)
              .order('created_at', ascending: false)
              .limit(100),
        );
        return (data as List)
            .map((json) => Event.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (_) {
        continue;
      }
    }

    try {
      final data = await _withSessionRetry(
        () => _client
            .from('events')
            .select(_legacy)
            .eq('is_published', true)
            .order('event_date', ascending: true),
      );
      return (data as List)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Event?> fetchById(String id) async {
    for (final select in eventRepositoryProviderFallbackSelects) {
      try {
        final row = await _withSessionRetry(
          () => _client
              .from('events')
              .select(select)
              .eq('id', id)
              .eq('is_published', true)
              .maybeSingle(),
        );
        if (row == null) return null;
        return Event.fromJson(Map<String, dynamic>.from(row));
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<bool> isFavorited(String eventId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await _withSessionRetry(
        () => _client
            .from('likes')
            .select('id')
            .eq('user_id', userId)
            .eq('target_id', eventId)
            .eq('target_type', 'event')
            .maybeSingle(),
      );
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> setFavorited(String eventId, {required bool favorited}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    if (favorited) {
      await _withSessionRetry(
        () => _client.from('likes').insert({
          'user_id': userId,
          'target_id': eventId,
          'target_type': 'event',
        }),
      );
    } else {
      await _withSessionRetry(
        () => _client
            .from('likes')
            .delete()
            .eq('user_id', userId)
            .eq('target_id', eventId)
            .eq('target_type', 'event'),
      );
    }
  }

  Future<List<Event>> fetchFavoritedEvents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final likes = await _withSessionRetry(
      () => _client
          .from('likes')
          .select('target_id')
          .eq('user_id', userId)
          .eq('target_type', 'event'),
    );
    final ids = (likes as List)
        .map((row) => (row as Map<String, dynamic>)['target_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];

    for (final select in eventRepositoryProviderFallbackSelects) {
      try {
        final rows = await _withSessionRetry(
          () => _client
              .from('events')
              .select(select)
              .inFilter('id', ids)
              .eq('is_published', true),
        );
        final byId = {
          for (final row in rows as List)
            (row as Map<String, dynamic>)['id'] as String: Event.fromJson(row),
        };
        return ids.map((id) => byId[id]).whereType<Event>().toList();
      } catch (_) {
        continue;
      }
    }
    return const [];
  }
}
