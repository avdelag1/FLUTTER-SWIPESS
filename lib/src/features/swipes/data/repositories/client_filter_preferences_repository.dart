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
      await _client.from('client_filter_preferences').upsert({
        ...filter.toPreferencesPayload(),
        'user_id': userId,
      }, onConflict: 'user_id');
    } catch (_) {
      // Offline / RLS failure — session filter already applied locally.
    }
  }

  /// Adds the signed-in user's current search intent to `client_profiles`.
  /// Intentions are additive: someone can simultaneously be a buyer, renter,
  /// worker-seeker, motorcycle renter, etc. Nothing is removed implicitly.
  Future<void> activateDiscoveryIntent({
    required String category,
    required String interestType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await _client
          .from('client_profiles')
          .select('intentions')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return;

      final current = <String>{};
      final raw = row['intentions'];
      if (raw is List) {
        current.addAll(
          raw
              .map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty),
        );
      }

      void addBuyRent(String noun) {
        if (interestType == 'sale' || interestType == 'both') {
          current.add('buy_$noun');
        }
        if (interestType == 'rent' || interestType == 'both') {
          current.add('rent_$noun');
        }
      }

      switch (category) {
        case 'buyers':
          current.add('buy_property');
          break;
        case 'renters':
          current.add('rent_property');
          break;
        case 'seekers':
        case 'worker':
          current.add('hire_service');
          break;
        case 'property':
          addBuyRent('property');
          break;
        case 'motorcycle':
          addBuyRent('motorcycle');
          break;
        case 'bicycle':
          addBuyRent('bicycle');
          break;
        case 'yacht':
          addBuyRent('yacht');
          break;
      }

      await _client
          .from('client_profiles')
          .update({'intentions': current.toList(growable: false)})
          .eq('user_id', userId);
    } catch (_) {
      // Search remains usable offline; visibility will sync on a later apply.
    }
  }
}
