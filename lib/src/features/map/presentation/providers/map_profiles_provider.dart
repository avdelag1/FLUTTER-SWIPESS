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

  try {
    final data = await client.rpc(
      'get_passport_map_profiles',
      params: {
        'p_user_lat': loc.latitude,
        'p_user_lon': loc.longitude,
        'p_radius_km': loc.radiusKm,
        'p_limit': 120,
        'p_exclude_user_id': userId,
      },
    );
    return _inCityRadius(
      (data as List)
          .map((row) => Profile.fromJson(row as Map<String, dynamic>))
          .toList(),
      loc,
    );
  } catch (_) {
    try {
      final data = await client
          .from('client_profiles')
          .select(
            'user_id, name, city, bio, age, occupation, profile_images, latitude, longitude, location_updated_at',
          )
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .limit(200)
          .timeout(const Duration(seconds: 8));
      return _inCityRadius(
        (data as List)
            .map((row) => Profile.fromJson(row as Map<String, dynamic>))
            .toList(),
        loc,
      );
    } catch (_) {
      return const [];
    }
  }
});

List<Profile> _inCityRadius(List<Profile> rows, DiscoveryLocation loc) {
  const haversine = Distance();
  final center = LatLng(loc.latitude, loc.longitude);
  final city = loc.city.trim().toLowerCase();
  return [
    for (final profile in rows)
      if (profile.latitude != null && profile.longitude != null)
        if (haversine.as(
              LengthUnit.Kilometer,
              center,
              LatLng(profile.latitude!, profile.longitude!),
            ) <=
            loc.radiusKm)
          profile
        else if (city.isNotEmpty &&
            (profile.city ?? '').toLowerCase().contains(city))
          profile,
  ];
}
