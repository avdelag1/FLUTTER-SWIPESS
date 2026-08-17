import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

final mapListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final loc = ref.watch(discoveryLocationProvider);
  final client = Supabase.instance.client;
  final limit = loc.radiusKm >= 5000
      ? 1000
      : loc.radiusKm >= 500
      ? 600
      : 300;

  final merged = <String, Listing>{};

  try {
    final data = await client
        .rpc(
          'get_passport_map_listings',
          params: {
            'p_user_lat': loc.latitude,
            'p_user_lon': loc.longitude,
            'p_radius_km': loc.radiusKm,
            'p_limit': limit,
          },
        )
        .timeout(const Duration(seconds: 8));
    for (final row in data as List) {
      final listing = Listing.fromJson(row as Map<String, dynamic>);
      merged[listing.id] = listing;
    }
  } catch (_) {
    // City/table fallback below still keeps the map usable when the RPC fails.
  }

  for (final listing in await _fetchRegisteredCityListings(
    client,
    loc,
    limit,
  )) {
    merged[listing.id] = listing;
  }

  if (merged.isEmpty) {
    for (final listing in await _fallbackListings(client, loc, limit)) {
      merged[listing.id] = listing;
    }
  }

  return _forMap(merged.values.toList(growable: false), loc);
});

List<Listing> _forMap(List<Listing> rows, DiscoveryLocation loc) {
  const haversine = Distance();
  final center = LatLng(loc.latitude, loc.longitude);
  final city = _normalizeCity(loc.city);

  return [
    for (final listing in rows)
      if (_sameCity(listing.city, city) ||
          (listing.latitude != null &&
              listing.longitude != null &&
              haversine.as(
                    LengthUnit.Kilometer,
                    center,
                    LatLng(listing.latitude!, listing.longitude!),
                  ) <=
                  loc.radiusKm))
        listing,
  ];
}

Future<List<Listing>> _fetchRegisteredCityListings(
  SupabaseClient client,
  DiscoveryLocation loc,
  int limit,
) async {
  final city = loc.city.trim();
  if (city.isEmpty || city.toLowerCase() == 'near you') return const [];

  Future<List<Listing>> fetch({required bool withStatus}) async {
    var query = client
        .from('listings')
        .select(
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, status, is_active, bedrooms, bathrooms',
        );
    query = query.eq('is_active', true).ilike('city', '%$city%');
    if (withStatus) query = query.eq('status', 'active');
    final data = await query.limit(limit).timeout(const Duration(seconds: 8));
    return (data as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  try {
    return await fetch(withStatus: true);
  } catch (_) {
    try {
      return await fetch(withStatus: false);
    } catch (_) {
      return const [];
    }
  }
}

Future<List<Listing>> _fallbackListings(
  SupabaseClient client,
  DiscoveryLocation loc,
  int limit,
) async {
  Future<List<Listing>> fetch({required bool withStatus}) async {
    var query = client
        .from('listings')
        .select(
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, status, is_active, bedrooms, bathrooms',
        );
    query = query.eq('is_active', true);
    if (withStatus) query = query.eq('status', 'active');
    final data = await query.limit(limit).timeout(const Duration(seconds: 8));
    return (data as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  try {
    return await fetch(withStatus: true);
  } catch (_) {
    try {
      return await fetch(withStatus: false);
    } catch (_) {
      return const [];
    }
  }
}

String _normalizeCity(String? value) => (value ?? '')
    .trim()
    .toLowerCase()
    .replaceAll('ú', 'u')
    .replaceAll('í', 'i');

bool _sameCity(String? value, String normalizedCity) {
  if (normalizedCity.isEmpty || normalizedCity == 'near you') return false;
  final normalizedValue = _normalizeCity(value);
  return normalizedValue == normalizedCity ||
      normalizedValue.contains(normalizedCity) ||
      normalizedCity.contains(normalizedValue);
}
