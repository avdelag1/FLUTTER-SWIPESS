import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return (data as List)
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();
  } catch (_) {
    try {
      final data = await client
          .from('client_profiles')
          .select(
            'user_id, name, city, bio, age, occupation, profile_images, latitude, longitude, location_updated_at',
          )
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .limit(80)
          .timeout(const Duration(seconds: 8));
      return (data as List)
          .map((row) => Profile.fromJson(row as Map<String, dynamic>))
          .where((p) => p.latitude != null && p.longitude != null)
          .toList();
    } catch (_) {
      return const [];
    }
  }
});
