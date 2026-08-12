import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

class EventRepository {
  final SupabaseClient _client;

  EventRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Event>> fetchEvents() async {
    final data = await _client
        .from('events')
        .select('id, title, description, category, image_url, event_date, location, location_detail, organizer_name, is_free, price_text, promo_text, discount_tag')
        .eq('is_published', true)
        .order('event_date', ascending: true);

    return (data as List).map((json) => Event.fromJson(json)).toList();
  }
}
