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
  final decidedIdsFuture = _fetchDecidedTargetIds(client, 'profile');
  final limit = loc.radiusKm >= 5000
      ? 1000
      : loc.radiusKm >= 500
      ? 600
      : 300;

  final merged = <String, Profile>{};
  final cityProfilesFuture = _fetchRegisteredCityProfiles(
    client,
    loc,
    limit,
    userId,
  );

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
        .timeout(const Duration(seconds: 5));
    for (final profile in _parseRows(data)) {
      if (profile.id != userId && profile.id.isNotEmpty) {
        merged[profile.id] = profile;
      }
    }
  } catch (_) {}

  for (final profile in await cityProfilesFuture) {
    if (profile.id != userId && profile.id.isNotEmpty) {
      merged[profile.id] = profile;
    }
  }

  if (merged.isEmpty) {
    for (final profile in await _fallbackProfiles(client, limit, userId)) {
      if (profile.id != userId && profile.id.isNotEmpty) {
        merged[profile.id] = profile;
      }
    }
  }

  final inArea = _forMap(merged.values.toList(growable: false), loc);
  final discoverable = await _filterDiscoverable(client, inArea);

  // People follow the same strict unseen-only Map rule as listings: once the
  // user has made either a right/save or left/dismiss decision, do not recycle
  // that person in the map tray or pins.
  final decidedIds = await decidedIdsFuture;
  if (decidedIds == null || decidedIds.isEmpty) return discoverable;
  return discoverable
      .where((profile) => !decidedIds.contains(profile.id))
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
    return null;
  }
}

Future<List<Profile>> _filterDiscoverable(
  SupabaseClient client,
  List<Profile> profiles,
) async {
  if (profiles.isEmpty || client.auth.currentUser == null) return profiles;
  try {
    final data = await client
        .rpc(
          'rpc_filter_discoverable_profile_ids',
          params: {'p_ids': profiles.map((e) => e.id).toList()},
        )
        .timeout(const Duration(seconds: 4));
    if (data is! List) return const [];
    final visible = data.map((e) => e.toString()).toSet();
    return profiles.where((profile) => visible.contains(profile.id)).toList();
  } catch (_) {
    return const [];
  }
}

List<Profile> _parseRows(dynamic data) {
  if (data is! List) return const [];
  final parsed = <Profile>[];
  for (final raw in data) {
    if (raw is! Map) continue;
    try {
      final profile = Profile.fromJson(Map<String, dynamic>.from(raw));
      if (profile.id.isNotEmpty) parsed.add(profile);
    } catch (_) {}
  }
  return parsed;
}

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
    final data = await query.limit(limit).timeout(const Duration(seconds: 5));
    return _parseRows(data);
  } catch (_) {
    return const [];
  }
}

Future<List<Profile>> _fallbackProfiles(
  SupabaseClient client,
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
    final data = await query.limit(limit).timeout(const Duration(seconds: 5));
    return _parseRows(data);
  } catch (_) {
    return const [];
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
