import 'package:flutter_swipes/src/features/profile_insights/domain/profile_insight_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileInsightsRepository {
  ProfileInsightsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ProfileInsightsSummary> fetchSummary({int days = 30}) async {
    final rows = await _client.rpc(
      'rpc_profile_insights_summary',
      params: <String, dynamic>{'p_days': days},
    );
    if (rows is List && rows.isEmpty) {
      return const ProfileInsightsSummary();
    }
    if (rows is List && rows.first is Map) {
      return ProfileInsightsSummary.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    }
    throw StateError('Profile Insights returned an unexpected summary payload.');
  }

  Future<List<ProfileInsightContact>> fetchContacts({
    int days = 30,
    int limit = 50,
  }) async {
    final rows = await _client.rpc(
      'rpc_profile_insight_contacts',
      params: <String, dynamic>{'p_days': days, 'p_limit': limit},
    );
    if (rows is! List) {
      throw StateError('Profile Insights returned an unexpected contacts payload.');
    }
    return rows
        .whereType<Map>()
        .map(
          (row) => ProfileInsightContact.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }
}
