import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

class EventRepository {
  final SupabaseClient _client;

  EventRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // Keep the current production schema first so opening Events does not waste
  // a network round-trip on columns that are not present in the live table.
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

  /// Matches Capacitor `useEventsDeck`: newest events, with video when present.
  Future<List<Event>> fetchEvents() async {
    for (final select in eventRepositoryProviderFallbackSelects) {
      try {
        final data = await _client
            .from('events')
            .select(select)
            .eq('is_published', true)
            .order('created_at', ascending: false)
            .limit(100);
        return (data as List)
            .map((json) => Event.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (_) {
        continue;
      }
    }

    try {
      final data = await _client
          .from('events')
          .select(_legacy)
          .eq('is_published', true)
          .order('event_date', ascending: true);
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
        final row = await _client
            .from('events')
            .select(select)
            .eq('id', id)
            .maybeSingle();
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
      final row = await _client
          .from('likes')
          .select('id')
          .eq('user_id', userId)
          .eq('target_id', eventId)
          .eq('target_type', 'event')
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> setFavorited(String eventId, {required bool favorited}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    if (favorited) {
      await _client.from('likes').insert({
        'user_id': userId,
        'target_id': eventId,
        'target_type': 'event',
      });
    } else {
      await _client
          .from('likes')
          .delete()
          .eq('user_id', userId)
          .eq('target_id', eventId)
          .eq('target_type', 'event');
    }
  }

  /// Capacitor EventosLikes — favorited events for current user.
  Future<List<Event>> fetchFavoritedEvents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final likes = await _client
        .from('likes')
        .select('target_id')
        .eq('user_id', userId)
        .eq('target_type', 'event');

    final ids = (likes as List)
        .map((row) => (row as Map<String, dynamic>)['target_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];

    for (final select in eventRepositoryProviderFallbackSelects) {
      try {
        final rows = await _client
            .from('events')
            .select(select)
            .inFilter('id', ids);
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
