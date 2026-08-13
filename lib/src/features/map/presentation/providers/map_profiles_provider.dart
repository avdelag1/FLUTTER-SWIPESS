import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';

final mapProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  final client = Supabase.instance.client;
  
  try {
    final data = await client.from('profiles')
        .select('id, full_name, username, avatar_url, bio, city, role, latitude, longitude, created_at, verified')
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
});
