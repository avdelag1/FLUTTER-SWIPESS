import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/user_profile.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';

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
          .select('user_id, name, bio, city, age, interests, profile_images')
          .eq('user_id', user.id)
          .maybeSingle();
      if (client != null) {
        final images = client['profile_images'];
        final imageList = images is List ? images : const [];
        final interestsRaw = client['interests'];
        return UserProfile(
          userId: user.id,
          name: (client['name'] as String?)?.trim().isNotEmpty == true
              ? client['name'] as String
              : (user.email ?? 'Swipess member'),
          bio: client['bio'] as String?,
          city: client['city'] as String?,
          age: (client['age'] as num?)?.toInt(),
          interests: interestsRaw is List
              ? interestsRaw.whereType<String>().toList()
              : const [],
          imageCount: imageList.length,
          avatarUrl: imageList.isNotEmpty
              ? imageList.first.toString()
              : user.userMetadata?['avatar_url'] as String?,
          email: user.email,
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
        final imageList = images is List ? images : const [];
        return UserProfile(
          userId: user.id,
          name: (owner['business_name'] as String?)?.trim().isNotEmpty == true
              ? owner['business_name'] as String
              : (user.email ?? 'Swipess member'),
          city: owner['city'] as String?,
          imageCount: imageList.length,
          avatarUrl: imageList.isNotEmpty ? imageList.first.toString() : null,
          email: user.email,
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
      email: user.email,
    );
  }

  Future<Profile?> fetchCurrentProfile() async {
    final user = await fetchCurrent();
    if (user == null) return null;
    return Profile(
      id: user.userId,
      fullName: user.name,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      city: user.city,
      role: user.role,
    );
  }

  Future<void> updateProfile({
    required String displayName,
    String? bio,
    String? city,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    try {
      await _client.from('client_profiles').update({
        'name': displayName,
        'bio': bio,
        'city': city,
      }).eq('user_id', user.id);
    } catch (_) {
      await _client.from('owner_profiles').update({
        'business_name': displayName,
        'city': city,
      }).eq('user_id', user.id);
    }
  }
}
