import 'package:flutter_swipes/src/features/profile_insights/domain/profile_insight_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileInsightsRepository {
  ProfileInsightsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ProfileInsightsSummary> fetchSummary({int days = 30}) async {
    try {
      final rows = await _client.rpc(
        'rpc_profile_insights_summary',
        params: <String, dynamic>{'p_days': days},
      );
      if (rows is List && rows.isNotEmpty && rows.first is Map) {
        return ProfileInsightsSummary.fromJson(
          Map<String, dynamic>.from(rows.first as Map),
        );
      }
    } catch (_) {}
    return const ProfileInsightsSummary();
  }

  Future<List<ProfileInsightContact>> fetchContacts({
    int days = 30,
    int limit = 50,
  }) async {
    try {
      final rows = await _client.rpc(
        'rpc_profile_insight_contacts',
        params: <String, dynamic>{'p_days': days, 'p_limit': limit},
      );
      if (rows is List) {
        return rows
            .whereType<Map>()
            .map(
              (row) => ProfileInsightContact.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList();
      }
    } catch (_) {}
    return const <ProfileInsightContact>[];
  }
}
