import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

class EventRepository {
  final SupabaseClient _client;

  EventRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const _withAudio =
      'id, title, description, category, image_url, image_urls, video_url, video_audio_enabled, background_music_url, event_date, location, location_detail, organizer_name, promo_text, discount_tag, is_free, price_text, created_at';
  static const _base =
      'id, title, description, category, image_url, image_urls, video_url, event_date, location, location_detail, organizer_name, promo_text, discount_tag, is_free, price_text, created_at';
  static const _legacy =
      'id, title, description, category, image_url, event_date, location, location_detail, organizer_name, is_free, price_text, promo_text, discount_tag';

  /// Matches Capacitor `useEventsDeck`: newest events, with video when present.
  Future<List<Event>> fetchEvents() async {
    for (final select in [_withAudio, _base, _legacy]) {
      try {
        final data = await _client
            .from('events')
            .select(select)
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
}
