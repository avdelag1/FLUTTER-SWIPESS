import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/user_profile.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile?> fetchCurrent({String? expectedUserId}) async {
    final user = _client.auth.currentUser;
    if (user == null || (expectedUserId != null && user.id != expectedUserId)) {
      return null;
    }

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
          avatarUrl: imageList.isNotEmpty ? imageList.first.toString() : null,
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
      name:
          user.userMetadata?['full_name'] as String? ??
          user.email ??
          'Swipess member',
      avatarUrl: null,
      email: user.email,
    );
  }

  Future<Profile?> fetchCurrentProfile({String? expectedUserId}) async {
    final user = await fetchCurrent(expectedUserId: expectedUserId);
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

  Future<({bool available, double? monthlyBudget})>
  fetchRoommatePreferences() async {
    final user = _client.auth.currentUser;
    if (user == null) return (available: false, monthlyBudget: null);
    try {
      final row = await _client
          .from('client_profiles')
          .select('roommate_available, monthly_budget')
          .eq('user_id', user.id)
          .maybeSingle();
      return (
        available: row?['roommate_available'] == true,
        monthlyBudget: (row?['monthly_budget'] as num?)?.toDouble(),
      );
    } catch (_) {
      return (available: false, monthlyBudget: null);
    }
  }

  Future<void> updateRoommatePreferences({
    required bool available,
    double? monthlyBudget,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await _client
        .from('client_profiles')
        .update({
          'roommate_available': available,
          'monthly_budget': available ? monthlyBudget : null,
        })
        .eq('user_id', user.id);
  }

  /// Cap `persistClientProfileGps`. Stamps `location_source = 'device'` so the
  /// Passport map can tell a real phone position from a city-centroid backfill,
  /// and falls back to plain coordinates on a database that predates those two
  /// columns. Throttling is the caller's job — see `ProfileGpsService`.
  Future<void> persistDeviceLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _client
          .from('client_profiles')
          .update({
            'latitude': latitude,
            'longitude': longitude,
            'location_updated_at': DateTime.now().toUtc().toIso8601String(),
            'location_source': 'device',
          })
          .eq('user_id', userId);
    } catch (_) {
      await _client
          .from('client_profiles')
          .update({'latitude': latitude, 'longitude': longitude})
          .eq('user_id', userId);
    }
  }

  Future<void> updateProfile({
    required String displayName,
    String? bio,
    String? city,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    try {
      await _client
          .from('client_profiles')
          .update({'name': displayName, 'bio': bio, 'city': city})
          .eq('user_id', user.id);
    } catch (_) {
      await _client
          .from('owner_profiles')
          .update({'business_name': displayName, 'city': city})
          .eq('user_id', user.id);
    }
  }

  Future<bool> fetchMapVisibleOnPassport() async {
    final user = _client.auth.currentUser;
    if (user == null) return true;
    try {
      final row = await _client
          .from('client_profiles')
          .select('map_visible, map_force_hidden')
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) return true;
      final userVisible = row['map_visible'] as bool? ?? true;
      final adminHidden = row['map_force_hidden'] as bool? ?? false;
      return userVisible && !adminHidden;
    } catch (_) {
      return true;
    }
  }

  Future<void> updateMapVisibleOnPassport(bool visible) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    try {
      await _client
          .from('client_profiles')
          .update({
            'map_visible': visible,
            'location_updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id);
    } catch (_) {
      await _client
          .from('client_profiles')
          .update({'map_visible': visible})
          .eq('user_id', user.id);
    }
  }

  Future<String?> fetchMapStatus() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('client_profiles')
          .select('map_status')
          .eq('user_id', user.id)
          .maybeSingle();
      final status = row?['map_status'] as String?;
      return status == null || status.trim().isEmpty ? null : status;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateMapStatus(String? status) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await _client
        .from('client_profiles')
        .update({'map_status': status})
        .eq('user_id', user.id);
  }
}
