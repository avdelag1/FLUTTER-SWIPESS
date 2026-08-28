import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

final mapListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final loc = ref.watch(discoveryLocationProvider);
  final client = Supabase.instance.client;
  final decidedIdsFuture = _fetchDecidedTargetIds(client, 'listing');
  final limit = loc.radiusKm >= 5000
      ? 400
      : loc.radiusKm >= 500
      ? 250
      : 180;

  final merged = <String, Listing>{};
  var rpcSucceeded = false;

  final cityListingsFuture = _fetchRegisteredCityListings(client, loc, limit);

  try {
    final data = await client
        .rpc(
          'get_passport_map_listings',
          params: {
            'p_user_lat': loc.latitude,
            'p_user_lon': loc.longitude,
            'p_radius_km': loc.radiusKm,
            'p_limit': limit,
            'p_exclude_owner_id': client.auth.currentUser?.id,
          },
        )
        .timeout(const Duration(seconds: 5));
    rpcSucceeded = true;
    for (final listing in _parseRows(data)) {
      if (listing.id.isNotEmpty) merged[listing.id] = listing;
    }
  } catch (_) {
    // City/table + coordinate fallbacks below keep the map usable.
  }

  for (final listing in await cityListingsFuture) {
    if (listing.id.isNotEmpty) merged[listing.id] = listing;
  }

  if (!rpcSucceeded || merged.isEmpty) {
    for (final listing in await _fallbackListings(client, limit)) {
      if (listing.id.isNotEmpty) merged[listing.id] = listing;
    }
  }

  final inArea = _forMap(merged.values.toList(growable: false), loc);
  final discoverable = await _filterDiscoverable(client, inArea);

  // The map is a strict unseen-only surface. Any canonical swipe decision is
  // enough to remove a listing here: right means saved, left means dismissed.
  // The normal swipe deck may apply its own cooldown/reconsideration rules, but
  // Map must never recycle something the user has already acted on.
  final decidedIds = await decidedIdsFuture;
  if (decidedIds == null || decidedIds.isEmpty) return discoverable;
  return discoverable
      .where((listing) => !decidedIds.contains(listing.id))
      .toList(growable: false);
});

Future<Set<String>?> _fetchDecidedTargetIds(
  SupabaseClient client,
  String targetType,
) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const <String>{};

  try {
    final rows = await client
        .from('likes')
        .select('target_id')
        .eq('user_id', userId)
        .eq('target_type', targetType)
        .timeout(const Duration(seconds: 4));

    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['target_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  } catch (_) {
    // The server-side discoverability RPC below is still a safe fallback for
    // current decisions if this raw ID fetch is temporarily unavailable.
    return null;
  }
}

Future<List<Listing>> _filterDiscoverable(
  SupabaseClient client,
  List<Listing> listings,
) async {
  if (listings.isEmpty || client.auth.currentUser == null) return listings;
  try {
    final data = await client
        .rpc(
          'rpc_filter_discoverable_listing_ids',
          params: {'p_ids': listings.map((e) => e.id).toList()},
        )
        .timeout(const Duration(seconds: 4));
    if (data is! List) return listings;
    final visible = data.map((e) => e.toString()).toSet();
    return listings.where((listing) => visible.contains(listing.id)).toList();
  } catch (_) {
    return listings;
  }
}

List<Listing> _parseRows(dynamic data) {
  if (data is! List) return const [];
  final parsed = <Listing>[];
  for (final raw in data) {
    if (raw is! Map) continue;
    try {
      final row = Map<String, dynamic>.from(raw);
      final listing = Listing.fromJson(row);
      if (listing.id.isNotEmpty) parsed.add(listing);
    } catch (_) {
      // Skip only the malformed row. One bad listing must never blank the map.
    }
  }
  return parsed;
}

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
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, status, is_active, beds, baths',
        );
    query = query.eq('is_active', true).ilike('city', '%$city%');
    if (withStatus) query = query.eq('status', 'active');
    final data = await query.limit(limit).timeout(const Duration(seconds: 5));
    return _parseRows(data);
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
  int limit,
) async {
  Future<List<Listing>> fetch({required bool withStatus}) async {
    var query = client
        .from('listings')
        .select(
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, status, is_active, beds, baths',
        );
    query = query.eq('is_active', true);
    if (withStatus) query = query.eq('status', 'active');
    final data = await query.limit(limit).timeout(const Duration(seconds: 5));
    return _parseRows(data);
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
    .replaceAll('í', 'i')
    .replaceAll('é', 'e')
    .replaceAll('á', 'a')
    .replaceAll('ó', 'o');

bool _sameCity(String? value, String normalizedCity) {
  if (normalizedCity.isEmpty || normalizedCity == 'near you') return false;
  final normalizedValue = _normalizeCity(value);
  if (normalizedValue.isEmpty) return false;
  return normalizedValue == normalizedCity ||
      normalizedValue.contains(normalizedCity) ||
      normalizedCity.contains(normalizedValue);
}
