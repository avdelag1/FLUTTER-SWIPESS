import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/user_profile.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile?> fetchCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final client = await _client
          .from('client_profiles')
          .select('user_id, name, bio, city, profile_images')
          .eq('user_id', user.id)
          .maybeSingle();
      if (client != null) {
        final images = client['profile_images'];
        return UserProfile(
          userId: user.id,
          name: (client['name'] as String?)?.trim().isNotEmpty == true
              ? client['name'] as String
              : (user.email ?? 'Swipess member'),
          bio: client['bio'] as String?,
          city: client['city'] as String?,
          avatarUrl: images is List && images.isNotEmpty
              ? images.first.toString()
              : user.userMetadata?['avatar_url'] as String?,
          role: 'client',
        );
      }
    } catch (_) {}

    try {
      final owner = await _client
          .from('owner_profiles')
          .select('user_id, business_name, city, profile_images')
          .eq('user_id', user.id)
          .maybeSingle();
      if (owner != null) {
        final images = owner['profile_images'];
        return UserProfile(
          userId: user.id,
          name: (owner['business_name'] as String?)?.trim().isNotEmpty == true
              ? owner['business_name'] as String
              : (user.email ?? 'Swipess member'),
          city: owner['city'] as String?,
          avatarUrl: images is List && images.isNotEmpty
              ? images.first.toString()
              : null,
          role: 'owner',
        );
      }
    } catch (_) {}

    return UserProfile(
      userId: user.id,
      name: user.userMetadata?['full_name'] as String? ??
          user.email ??
          'Swipess member',
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }
}
