import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

final mapListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final loc = ref.watch(discoveryLocationProvider);
  final client = Supabase.instance.client;

  try {
    final data = await client.rpc(
      'get_passport_map_listings',
      params: {
        'p_user_lat': loc.latitude,
        'p_user_lon': loc.longitude,
        'p_radius_km': loc.radiusKm,
        'p_limit': 120,
      },
    );
    return (data as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();
  } catch (_) {
    return _fallbackListings(client);
  }
});

Future<List<Listing>> _fallbackListings(SupabaseClient client) async {
  Future<List<Listing>> fetch({required bool withStatus}) async {
    var query = client.from('listings').select(
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, status, is_active, bedrooms, bathrooms',
        );
    query = query.eq('is_active', true);
    if (withStatus) {
      query = query.eq('status', 'active');
    }
    final data = await query
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .limit(80);
    return (data as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();
  }

  try {
    return await fetch(withStatus: true).timeout(const Duration(seconds: 8));
  } catch (_) {
    try {
      return await fetch(withStatus: false).timeout(const Duration(seconds: 8));
    } catch (_) {
      return const [];
    }
  }
}
