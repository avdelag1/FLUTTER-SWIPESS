import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/roommates/domain/roommate_filters.dart';
import 'package:flutter_swipes/src/features/roommates/domain/roommate_profile.dart';

final roommateFiltersProvider =
    NotifierProvider<RoommateFiltersNotifier, RoommateFilters>(
  RoommateFiltersNotifier.new,
);

class RoommateFiltersNotifier extends Notifier<RoommateFilters> {
  @override
  RoommateFilters build() => const RoommateFilters();

  void set(RoommateFilters next) => state = next;

  void reset() => state = const RoommateFilters();
}

final roommatesProvider = FutureProvider<List<RoommateProfile>>((ref) async {
  ref.watch(authStateProvider);
  final filters = ref.watch(roommateFiltersProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  List data;
  try {
    var query = client.from('client_profiles').select(
      'user_id, name, bio, vap_bio, city, vap_city, age, profile_images, vap_avatar, occupation, vap_occupation, budget, monthly_budget',
    );
    if (userId != null) {
      query = query.neq('user_id', userId);
    }
    data = await query.order('updated_at', ascending: false).limit(60) as List;
  } catch (_) {
    data = await client
        .from('client_profiles')
        .select('user_id, name, bio, city, age, profile_images')
        .limit(60) as List;
  }

  final profiles = data
      .map((row) => RoommateProfile.fromJson(row as Map<String, dynamic>))
      .where((p) {
        if (p.budget != null &&
            (p.budget! < filters.minBudget || p.budget! > filters.maxBudget)) {
          return false;
        }
        if (p.age != null &&
            (p.age! < filters.minAge || p.age! > filters.maxAge)) {
          return false;
        }
        if (filters.city != null &&
            filters.city!.isNotEmpty &&
            (p.city == null ||
                p.city!.toLowerCase() != filters.city!.toLowerCase())) {
          return false;
        }
        return true;
      })
      .toList();

  return profiles;
});
