import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final clientFilterPreferencesRepositoryProvider =
    Provider<ClientFilterPreferencesRepository>((ref) {
  return ClientFilterPreferencesRepository();
});

/// Cap `useClientFilterPreferences` — reads/writes `client_filter_preferences`,
/// upserted by `user_id`. Mirrors only the fields the Flutter filter sheet
/// exposes; extra Cap-only fields (moto/bicycle sub-filters) are left alone.
class ClientFilterPreferencesRepository {
  ClientFilterPreferencesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Returns the signed-in user's saved preferences row, or null if signed
  /// out, offline, or no row exists yet. Never throws — callers fall back to
  /// the local/session filter state.
  Future<Map<String, dynamic>?> fetchOwn() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      return await _client
          .from('client_filter_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Maps a persisted row onto a [SwipeFilter], falling back to a fresh
  /// default filter for any column that's null/missing.
  SwipeFilter? toFilter(Map<String, dynamic>? row) {
    if (row == null) return null;
    return SwipeFilterPreferencesMapping.mergeFromPreferencesRow(
      SwipeFilter(),
      row,
    );
  }

  /// Upserts (by `user_id`) — no-op when signed out. Swallows failures so an
  /// offline apply still keeps the local/session filter working.
  Future<void> upsertFromFilter(SwipeFilter filter) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('client_filter_preferences').upsert(
        {...filter.toPreferencesPayload(), 'user_id': userId},
        onConflict: 'user_id',
      );
    } catch (_) {
      // Offline / RLS failure — session filter already applied locally.
    }
  }
}
