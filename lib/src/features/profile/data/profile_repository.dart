import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

final currentProfileProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final repo = ref.read(profileRepositoryProvider);
  return repo.fetchCurrentProfile();
});

class ProfileRepository {
  final SupabaseClient _client;
  ProfileRepository(this._client);

  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // First try client_profiles
    final clientData = await _client
        .from('client_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (clientData != null) {
      clientData['role_type'] = 'client';
      return clientData;
    }

    // Then try owner_profiles
    final ownerData = await _client
        .from('owner_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (ownerData != null) {
      ownerData['role_type'] = 'owner';
    }

    return ownerData;
  }
}
