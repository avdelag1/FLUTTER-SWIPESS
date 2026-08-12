import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<Profile?> fetchCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select('id, full_name, username, avatar_url, bio, city, role, created_at, verified')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? city,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{};
    if (displayName != null) updates['full_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (city != null) updates['city'] = city;

    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', user.id);
  }
}
