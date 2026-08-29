import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

/// Event reads retry once after refreshing an authenticated Supabase session.
class EventRepository {
  EventRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  Future<List<Event>>? _eventsRequest;

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
    } on PostgrestException catch (e) {
      if (e.code == '42501') rethrow; // Permission denied. Refresh won't help.
      if (_client.auth.currentUser == null) rethrow;
      try {
        await _client.auth.refreshSession();
      } catch (_) {
        rethrow;
      }
      return action();
    }
  }

  /// Dashboard-only teaser feed. While the visible teaser loads, warm the real
  /// Events feed too. The same repository instance is shared by Riverpod, so a
  /// later tap on Events can render from the already-started cached request.
  Future<List<Event>> fetchDashboardVideoTeasers({int limit = 8}) async {
    unawaited(fetchEvents());
    try {
      final rows = await _client.rpc(
        'rpc_event_video_teasers',
        params: {'p_limit': limit},
      );
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) => Event.fromJson(Map<String, dynamic>.from(row)))
          .where((event) => event.videoUrl?.trim().isNotEmpty == true)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Event>> fetchEvents({bool forceRefresh = false}) {
    if (forceRefresh) _eventsRequest = null;
    return _eventsRequest ??= _loadEvents();
  }

  Future<List<Event>> _loadEvents() async {
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
        final events = (data as List)
            .map((json) => Event.fromJson(json as Map<String, dynamic>))
            .toList();
        if (events.isNotEmpty) return events;
      } on PostgrestException catch (e) {
        if (e.code == '42501' ||
            e.message.contains('permission denied') ||
            e.message.contains('Forbidden')) {
          break;
        }
        continue;
      } catch (_) {
        continue;
      }
    }

    final rpcEvents = await _loadEventsFromRpc();
    if (rpcEvents.isNotEmpty) return rpcEvents;

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

  Future<List<Event>> _loadEventsFromRpc() async {
    try {
      final rows = await _client.rpc(
        'rpc_public_events_feed',
        params: {'p_limit': 100},
      );
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) => Event.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
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
      // `likes.direction` is shared with swipe decisions and is NOT NULL.
      // Events use `right` to represent a positive/save decision. Upsert makes
      // rapid double taps and retries idempotent instead of surfacing a unique
      // constraint error after the heart already turned on in the UI.
      await _withSessionRetry(
        () => _client.from('likes').upsert({
          'user_id': userId,
          'target_id': eventId,
          'target_type': 'event',
          'direction': 'right',
        }, onConflict: 'user_id,target_id,target_type'),
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
          .eq('target_type', 'event')
          .order('created_at', ascending: false),
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
