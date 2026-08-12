import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';

final vapIdRepositoryProvider = Provider<VapIdRepository>((ref) {
  return VapIdRepository();
});

class VapIdRepository {
  VapIdRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<VapIdCard?> fetch() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final card = await _client
          .from('vap_id_cards')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (card != null) {
        return VapIdCard.fromJson(card, user.id);
      }
    } catch (_) {}

    try {
      final legacy = await _client
          .from('client_profiles')
          .select(
            'vap_bio, vap_occupation, vap_city, vap_nationality, vap_years_in_city, vap_languages, vap_interests, vap_avatar, name, age, country, profile_images',
          )
          .eq('user_id', user.id)
          .maybeSingle();
      if (legacy != null) {
        final images = legacy['profile_images'];
        return VapIdCard.fromJson({
          ...legacy,
          'bio': legacy['vap_bio'],
          'occupation': legacy['vap_occupation'],
          'city': legacy['vap_city'],
          'avatar_url': legacy['vap_avatar'] ??
              (images is List && images.isNotEmpty ? images.first : null),
        }, user.id);
      }
    } catch (_) {}

    return VapIdCard(
      userId: user.id,
      name: user.userMetadata?['full_name'] as String? ??
          user.email?.split('@').first,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }

  Future<void> save(VapIdCard card) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await _client.from('vap_id_cards').upsert({
      'user_id': user.id,
      'name': card.name,
      'age': card.age,
      'country': card.country,
      'bio': card.bio,
      'occupation': card.occupation,
      'city': card.city,
      'nationality': card.nationality,
      'years_in_city': card.yearsInCity,
      'languages': card.languages,
      'interests': card.interests,
      'avatar_url': card.avatarUrl,
    }, onConflict: 'user_id');
  }
}
