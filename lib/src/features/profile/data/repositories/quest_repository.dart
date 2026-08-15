import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/profile/domain/daily_quest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  return QuestRepository();
});

/// Cap `useDailyQuests` — RPCs stay on Supabase; Flutter only invokes them.
class QuestRepository {
  QuestRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<DailyQuest>> fetchQuests() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      final data = await _client.rpc(
        'rpc_get_or_create_daily_quests',
        params: {'p_user_id': uid},
      );
      return _parse(data);
    } catch (_) {}
    return const [];
  }

  Future<int> fetchPoints() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final row = await _client
          .from('profiles')
          .select('quest_points')
          .eq('id', uid)
          .maybeSingle();
      return (row?['quest_points'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<DailyQuest>> increment({
    required String questId,
    int amount = 1,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    await fetchQuests();
    try {
      final data = await _client.rpc(
        'rpc_increment_quest_progress',
        params: {'p_user_id': uid, 'p_quest_id': questId, 'p_amount': amount},
      );
      return _parse(data);
    } catch (_) {}
    return const [];
  }

  Future<List<DailyQuest>> claim(String questId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    await fetchQuests();
    try {
      final data = await _client.rpc(
        'rpc_claim_quest_reward',
        params: {'p_user_id': uid, 'p_quest_id': questId},
      );
      return _parse(data);
    } catch (_) {}
    return const [];
  }

  List<DailyQuest> _parse(dynamic data) {
    var raw = data;
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return const [];
      }
    }
    if (raw is List) {
      return [
        for (final row in raw)
          if (row is Map) DailyQuest.fromJson(Map<String, dynamic>.from(row)),
      ];
    }
    return const [];
  }
}
