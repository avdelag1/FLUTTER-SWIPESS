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
      data =
          await filter.order('created_at', ascending: false).limit(50) as List;
    } catch (_) {
      // Fallback if mode/listing_type columns differ — worker requests by title.
      try {
        data =
            await _client
                    .from('listings')
                    .select(
                      'id, title, category, service_category, description, available_from, time_slots_available, minimum_booking_hours, days_available, price, pricing_unit, location, city, status, owner_id',
                    )
                    .eq('category', 'worker')
                    .eq('is_active', true)
                    .order('created_at', ascending: false)
                    .limit(50)
                as List;
      } catch (_) {
        return const [];
      }
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

  /// Cap SeekerRequestDialog — post a `listing_type=request` / `mode=seek` listing.
  Future<void> createRequest({
    required String categoryId,
    required String location,
    String? subcategory,
    String? description,
    String? budget,
    String pricingUnit = 'job',
    List<String> days = const [],
    String urgency = 'flexible',
    DateTime? availableFrom,
    String? time,
    double? durationHours,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    final title = subcategory == null || subcategory.isEmpty
        ? '$categoryId needed'
        : '$categoryId needed — $subcategory';

    final payload = <String, dynamic>{
      'owner_id': userId,
      'user_id': userId,
      'listing_type': 'request',
      'mode': 'seek',
      'is_active': true,
      'category': categoryId,
      'service_category': subcategory,
      'title': title[0].toUpperCase() + title.substring(1),
      'description': description,
      'available_from': availableFrom?.toIso8601String().split('T').first,
      'time_slots_available': time == null || time.isEmpty
          ? null
          : [
              {'start': time},
            ],
      'minimum_booking_hours': durationHours,
      'days_available': days.isEmpty ? null : days,
      'price': double.tryParse(budget ?? '') ?? 0,
      'pricing_unit': pricingUnit,
      'location': location,
      'city': location,
      'status': urgency,
    };
    payload.removeWhere((_, v) => v == null);

    // Schema-retry insert (same idea as listing save).
    var safe = Map<String, dynamic>.from(payload);
    final removed = <String>{};
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        await _client.from('listings').insert(safe);
        return;
      } catch (error) {
        final message = error.toString();
        final match = RegExp(
          r'''['"]([^'"]+)['"]\s+column|column\s+['"]([^'"]+)['"]|find the ['"]([^'"]+)['"] column''',
          caseSensitive: false,
        ).firstMatch(message);
        final missing = match?.group(1) ?? match?.group(2) ?? match?.group(3);
        if (missing == null ||
            !safe.containsKey(missing) ||
            removed.contains(missing)) {
          rethrow;
        }
        removed.add(missing);
        safe.remove(missing);
      }
    }
    throw Exception('Could not post seeker request.');
  }

  Future<Map<String, Map<String, dynamic>>> _loadProfiles(
    List<String> ids,
  ) async {
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
