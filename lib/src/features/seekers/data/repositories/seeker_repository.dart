import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_request.dart';

final seekerRepositoryProvider = Provider<SeekerRepository>((ref) {
  return SeekerRepository();
});

class SeekerRepository {
  SeekerRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Capacitor SeekersPage: listings with listing_type=request, mode=seek.
  Future<List<SeekerRequest>> fetchRequests() async {
    final userId = _client.auth.currentUser?.id;

    List data;
    try {
      var filter = _client
          .from('listings')
          .select(
            'id, title, category, service_category, description, available_from, time_slots_available, minimum_booking_hours, days_available, price, pricing_unit, location, city, status, owner_id',
          )
          .eq('listing_type', 'request')
          .eq('mode', 'seek')
          .eq('is_active', true);
      if (userId != null) {
        filter = filter.neq('owner_id', userId);
      }
      data = await filter.order('created_at', ascending: false).limit(50) as List;
    } catch (_) {
      // Fallback if mode/listing_type columns differ — worker requests by title.
      data = await _client
          .from('listings')
          .select(
            'id, title, category, service_category, description, available_from, time_slots_available, minimum_booking_hours, days_available, price, pricing_unit, location, city, status, owner_id',
          )
          .eq('category', 'worker')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(50) as List;
    }

    if (data.isEmpty) return const [];

    final ownerIds = data
        .map((row) => (row as Map)['owner_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final profiles = await _loadProfiles(ownerIds);

    return data.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final ownerId = map['owner_id'] as String?;
      final profile = ownerId == null ? null : profiles[ownerId];
      return SeekerRequest.fromJson(
        map,
        seekerName: profile?['name'] as String?,
        seekerAvatar: profile?['avatar'] as String?,
      );
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _loadProfiles(List<String> ids) async {
    if (ids.isEmpty) return {};
    final map = <String, Map<String, dynamic>>{};
    try {
      final rows = await _client
          .from('client_profiles')
          .select('user_id, name, profile_images')
          .inFilter('user_id', ids);
      for (final row in rows as List) {
        final r = row as Map<String, dynamic>;
        final images = r['profile_images'];
        map[r['user_id'] as String] = {
          'name': r['name'],
          'avatar': images is List && images.isNotEmpty ? images.first : null,
        };
      }
    } catch (_) {}
    return map;
  }
}
