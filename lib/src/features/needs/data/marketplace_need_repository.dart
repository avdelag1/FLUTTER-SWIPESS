import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/needs/domain/marketplace_need.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceNeedRepository {
  MarketplaceNeedRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<MarketplaceNeed> create(MarketplaceNeedDraft draft) async {
    final raw = await _client.rpc(
      'rpc_create_marketplace_need',
      params: draft.toRpcParams(),
    );
    if (raw is! Map) throw StateError('Invalid marketplace need response');
    return MarketplaceNeed.fromJson(raw);
  }

  Future<MarketplaceNeed> close(
    String needId, {
    String status = 'closed',
  }) async {
    final raw = await _client.rpc(
      'rpc_close_marketplace_need',
      params: {'p_need_id': needId, 'p_status': status},
    );
    if (raw is! Map) throw StateError('Invalid marketplace need response');
    return MarketplaceNeed.fromJson(raw);
  }

  Future<List<MarketplaceNeed>> mine({bool openOnly = false}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    dynamic query = _client
        .from('listings')
        .select()
        .eq('owner_id', uid)
        .eq('listing_type', 'request')
        .eq('mode', 'seek');
    if (openOnly) query = query.eq('is_active', true);
    final rows = await query.order('created_at', ascending: false).limit(100);
    return (rows as List)
        .map((row) => MarketplaceNeed.fromJson(row as Map))
        .toList(growable: false);
  }

  Future<List<MarketplaceNeed>> nearbyOpen({
    String? category,
    String? city,
    int limit = 50,
  }) async {
    dynamic query = _client
        .from('listings')
        .select()
        .eq('listing_type', 'request')
        .eq('mode', 'seek')
        .eq('is_active', true);
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (city != null && city.isNotEmpty) query = query.ilike('city', city);
    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 100));
    return (rows as List)
        .map((row) => MarketplaceNeed.fromJson(row as Map))
        .toList(growable: false);
  }

  /// Search is intentionally read-only: AI can find something without posting
  /// demand. Publishing an I Need request is a separate confirmation action.
  Future<List<Listing>> searchListings(
    MarketplaceNeedDraft draft, {
    int limit = 30,
  }) async {
    dynamic query = _client
        .from('listings')
        .select()
        .eq('is_active', true)
        .eq('category', draft.category)
        .neq('listing_type', 'request');
    if (draft.city != null && draft.city!.trim().isNotEmpty) {
      query = query.ilike('city', draft.city!.trim());
    }
    if (draft.budgetMax != null) query = query.lte('price', draft.budgetMax!);
    if (draft.budgetMin != null) query = query.gte('price', draft.budgetMin!);
    final rows = await query
        .order('updated_at', ascending: false)
        .limit(limit.clamp(1, 100));
    return (rows as List)
        .whereType<Map>()
        .map((row) => Listing.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<Listing>> findListingsForNeed(
    String needId, {
    int limit = 30,
  }) async {
    final rows = await _client.rpc(
      'rpc_find_listings_for_need',
      params: {'p_need_id': needId, 'p_limit': limit.clamp(1, 100)},
    );
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Listing.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}

final marketplaceNeedRepositoryProvider = Provider<MarketplaceNeedRepository>((ref) {
  return MarketplaceNeedRepository();
});

final myMarketplaceNeedsProvider = FutureProvider<List<MarketplaceNeed>>((ref) {
  return ref.read(marketplaceNeedRepositoryProvider).mine();
});
