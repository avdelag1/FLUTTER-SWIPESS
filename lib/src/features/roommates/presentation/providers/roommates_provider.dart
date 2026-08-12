import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/roommates/domain/roommate_profile.dart';

final roommatesProvider = FutureProvider<List<RoommateProfile>>((ref) async {
  ref.watch(authStateProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  List data;
  try {
    var filter = client.from('client_profiles').select(
      'user_id, name, bio, vap_bio, city, vap_city, age, profile_images, vap_avatar, occupation, vap_occupation, budget, monthly_budget',
    );
    if (userId != null) {
      filter = filter.neq('user_id', userId);
    }
    data = await filter.order('updated_at', ascending: false).limit(40) as List;
  } catch (_) {
    data = await client
        .from('client_profiles')
        .select('user_id, name, bio, city, age, profile_images')
        .limit(40) as List;
  }

  return data
      .map((row) => RoommateProfile.fromJson(row as Map<String, dynamic>))
      .toList();
});
