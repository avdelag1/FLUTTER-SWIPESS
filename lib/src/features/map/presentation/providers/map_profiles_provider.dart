import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';

final mapProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  final loc = ref.watch(discoveryLocationProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  final client = Supabase.instance.client;
  final limit = loc.radiusKm >= 5000
      ? 1000
      : loc.radiusKm >= 500
      ? 600
      : 300;

  final merged = <String, Profile>{};

  try {
    final data = await client
        .rpc(
          'get_passport_map_profiles',
          params: {
            'p_user_lat': loc.latitude,
            'p_user_lon': loc.longitude,
            'p_radius_km': loc.radiusKm,
            'p_limit': limit,
            'p_exclude_user_id': userId,
          },
        )
        .timeout(const Duration(seconds: 8));
    for (final row in data as List) {
      final profile = Profile.fromJson(row as Map<String, dynamic>);
      if (profile.id != userId) merged[profile.id] = profile;
    }
  } catch (_) {
    // City/table fallback below still keeps registered users discoverable.
  }

  for (final profile in await _fetchRegisteredCityProfiles(
    client,
    loc,
    limit,
    userId,
  )) {
    merged[profile.id] = profile;
  }

  if (merged.isEmpty) {
    for (final profile in await _fallbackProfiles(client, loc, limit, userId)) {
      merged[profile.id] = profile;
    }
  }

  return _forMap(merged.values.toList(growable: false), loc);
});

List<Profile> _forMap(List<Profile> rows, DiscoveryLocation loc) {
  const haversine = Distance();
  final center = LatLng(loc.latitude, loc.longitude);
  final city = _normalizeCity(loc.city);

  return [
    for (final profile in rows)
      if (_sameCity(profile.city, city) ||
          (profile.latitude != null &&
              profile.longitude != null &&
              haversine.as(
                    LengthUnit.Kilometer,
                    center,
                    LatLng(profile.latitude!, profile.longitude!),
                  ) <=
                  loc.radiusKm))
        profile,
  ];
}

Future<List<Profile>> _fetchRegisteredCityProfiles(
  SupabaseClient client,
  DiscoveryLocation loc,
  int limit,
  String? userId,
) async {
  final city = loc.city.trim();
  if (city.isEmpty || city.toLowerCase() == 'near you') return const [];

  try {
    var query = client
        .from('client_profiles')
        .select(
          'user_id, name, city, bio, age, occupation, profile_images, latitude, longitude, location_updated_at',
        );
    query = query.ilike('city', '%$city%');
    if (userId != null) query = query.neq('user_id', userId);
    final data = await query.limit(limit).timeout(const Duration(seconds: 8));
    return (data as List)
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

Future<List<Profile>> _fallbackProfiles(
  SupabaseClient client,
  DiscoveryLocation loc,
  int limit,
  String? userId,
) async {
  try {
    var query = client
        .from('client_profiles')
        .select(
          'user_id, name, city, bio, age, occupation, profile_images, latitude, longitude, location_updated_at',
        );
    if (userId != null) query = query.neq('user_id', userId);
    final data = await query.limit(limit).timeout(const Duration(seconds: 8));
    return (data as List)
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  } catch (_) {
    return const [];
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
