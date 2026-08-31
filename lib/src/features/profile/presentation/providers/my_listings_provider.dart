import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerListingsStats {
  const OwnerListingsStats({
    required this.total,
    required this.active,
    required this.views,
    required this.avgPrice,
    this.categories = 0,
  });
  final int total;
  final int active;
  final int views;
  final double avgPrice;
  final int categories;
}

int _activeCategoryCount(List<Listing> listings) {
  final properties = listings
      .where((l) => l.category == null || l.category == 'property')
      .isNotEmpty;
  final motorcycles = listings.any((l) => l.category == 'motorcycle');
  final bicycles = listings.any((l) => l.category == 'bicycle');
  final services = listings.any(
    (l) => l.category == 'worker' || l.category == 'services',
  );
  final vehicles = listings.any((l) => l.category == 'vehicle');
  return [
    properties,
    motorcycles,
    bicycles,
    services,
    vehicles,
  ].where((v) => v).length;
}

/// The signed-in owner's real listings.
///
/// Database/read failures must surface as an AsyncValue error instead of being
/// converted into an empty gallery. Otherwise a temporary query problem looks
/// exactly like all uploaded listings disappeared.
final myListingsProvider = FutureProvider.family<List<Listing>, String>((
  ref,
  status,
) async {
  ref.watch(authStateProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];

  var query = client.from('listings').select().eq('owner_id', userId);

  if (status == 'active') {
    query = query.or('status.eq.active,status.eq.available,is_active.eq.true');
  } else if (status == 'pending') {
    query = query.eq('status', 'pending');
  } else if (status == 'rented') {
    query = query.eq('status', 'rented');
  } else if (status == 'sold') {
    query = query.or('status.eq.sold,status.eq.closed');
  } else if (status == 'maintenance') {
    query = query.eq('status', 'maintenance');
  }

  final rows = await query
      .order('display_order', ascending: true)
      .order('created_at', ascending: false)
      .limit(100)
      .timeout(const Duration(seconds: 8));

  return (rows as List)
      .whereType<Map>()
      .map((row) => Listing.fromJson(Map<String, dynamic>.from(row)))
      .where((listing) => listing.id.isNotEmpty)
      .toList(growable: false);
});

final ownerListingsStatsProvider = FutureProvider<OwnerListingsStats>((
  ref,
) async {
  ref.watch(authStateProvider);
  final all = await ref.watch(myListingsProvider('all').future);
  if (all.isEmpty) {
    return const OwnerListingsStats(
      total: 0,
      active: 0,
      views: 0,
      avgPrice: 0,
      categories: 0,
    );
  }
  final prices = all.map((l) => l.price ?? 0).where((p) => p > 0).toList();
  final avg = prices.isEmpty
      ? 0.0
      : prices.reduce((a, b) => a + b) / prices.length;
  return OwnerListingsStats(
    total: all.length,
    active: all.where((l) => l.isActive == true || l.status == 'active').length,
    views: all.fold<int>(0, (sum, l) => sum + (l.views ?? 0)),
    avgPrice: avg,
    categories: _activeCategoryCount(all),
  );
});

class OwnerListingsActions {
  OwnerListingsActions(this._ref);
  final Ref _ref;

  SupabaseClient get _client => Supabase.instance.client;

  void _refresh() {
    _ref.invalidate(myListingsProvider);
    _ref.invalidate(ownerListingsStatsProvider);
  }

  Future<void> setStatus(String id, String status) async {
    await _ref
        .read(listingRepositoryProvider)
        .updateListingStatus(listingId: id, status: status);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _ref.read(listingRepositoryProvider).deleteListing(id);
    _refresh();
  }

  /// Persist the exact order chosen by the owner. The RPC validates every id
  /// belongs to auth.uid(), so one user can never reorder another user's page.
  Future<void> reorder(List<String> listingIds) async {
    if (listingIds.isEmpty) return;
    await _client.rpc(
      'rpc_reorder_my_listings',
      params: {'p_ids': listingIds},
    );
    _refresh();
  }

  /// The first image is the listing cover everywhere in Flutter. Persisting a
  /// reordered image array therefore updates both gallery order and card cover.
  Future<void> reorderImages({
    required String listingId,
    required List<String> imageUrls,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    if (imageUrls.isEmpty) {
      throw ArgumentError('A listing needs at least 1 photo');
    }

    await _client
        .from('listings')
        .update({'images': imageUrls})
        .eq('id', listingId)
        .eq('owner_id', userId);
    _refresh();
  }
}

final ownerListingsActionsProvider = Provider<OwnerListingsActions>(
  (ref) => OwnerListingsActions(ref),
);
