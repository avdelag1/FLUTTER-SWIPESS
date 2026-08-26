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

final myListingsProvider = FutureProvider.family<List<Listing>, String>((
  ref,
  status,
) async {
  ref.watch(authStateProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];

  Future<List<Listing>> primary() async {
    var filter = client
        .from('listings')
        .select(
          'id, owner_id, title, description, price, images, image_url, city, neighborhood, category, listing_type, latitude, longitude, currency, status, is_active, views, likes, created_at, amenities, furnished, pet_friendly, property_type, beds, baths, video_url, vehicle_brand, vehicle_model, year, mileage, service_category',
        )
        .eq('owner_id', userId);
    if (status == 'active') {
      filter = filter.or(
        'status.eq.active,status.eq.available,is_active.eq.true',
      );
    } else if (status == 'pending') {
      filter = filter.eq('status', 'pending');
    } else if (status == 'rented') {
      filter = filter.eq('status', 'rented');
    } else if (status == 'sold') {
      filter = filter.or('status.eq.sold,status.eq.closed');
    } else if (status == 'maintenance') {
      filter = filter.eq('status', 'maintenance');
    }
    final rows = await filter
        .order('created_at', ascending: false)
        .limit(100)
        .timeout(const Duration(seconds: 6));
    return (rows as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Listing>> fallback() async {
    final rows = await client
        .from('listings')
        .select(
          'id, owner_id, title, description, price, images, image_url, city, neighborhood, category, listing_type, latitude, longitude, currency, is_active, status, views, likes, amenities, furnished, pet_friendly, property_type, beds, baths, video_url',
        )
        .eq('owner_id', userId)
        .limit(100)
        .timeout(const Duration(seconds: 4));
    final all = (rows as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
    if (status == 'active')
      return all
          .where((l) => l.isActive == true || l.status == 'active')
          .toList();
    if (status == 'all') return all;
    return all.where((l) => l.status == status).toList();
  }

  try {
    return await primary();
  } catch (_) {
    try {
      return await fallback();
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }
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
  Future<void> setStatus(String id, String status) async {
    await _ref
        .read(listingRepositoryProvider)
        .updateListingStatus(listingId: id, status: status);
    _ref.invalidate(myListingsProvider);
    _ref.invalidate(ownerListingsStatsProvider);
  }

  Future<void> delete(String id) async {
    await _ref.read(listingRepositoryProvider).deleteListing(id);
    _ref.invalidate(myListingsProvider);
    _ref.invalidate(ownerListingsStatsProvider);
  }
}

final ownerListingsActionsProvider = Provider<OwnerListingsActions>(
  (ref) => OwnerListingsActions(ref),
);
