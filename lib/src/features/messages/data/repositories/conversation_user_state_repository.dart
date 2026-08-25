import 'package:supabase_flutter/supabase_flutter.dart';

/// Per-user state for a shared conversation.
///
/// Hiding/deleting a chat from one inbox must never erase the other
/// participant's copy. The backing table is protected by participant-aware
/// RLS and stores only the current user's archived/hidden state.
class ConversationUserStateRepository {
  ConversationUserStateRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, Map<String, dynamic>>> fetchMine(
    Iterable<String> conversationIds,
  ) async {
    final userId = _client.auth.currentUser?.id;
    final ids = conversationIds.toSet().toList();
    if (userId == null || ids.isEmpty) return const {};

    final rows = await _client
        .from('conversation_user_state')
        .select('conversation_id, hidden_at, archived_at')
        .eq('user_id', userId)
        .inFilter('conversation_id', ids);

    return {
      for (final raw in rows as List)
        (raw as Map<String, dynamic>)['conversation_id'].toString(): raw,
    };
  }

  Future<void> hideMany(Iterable<String> conversationIds) async {
    final userId = _client.auth.currentUser?.id;
    final ids = conversationIds.toSet().where((id) => id.isNotEmpty).toList();
    if (userId == null || ids.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('conversation_user_state').upsert(
      [
        for (final id in ids)
          {
            'conversation_id': id,
            'user_id': userId,
            'hidden_at': now,
            'updated_at': now,
          },
      ],
      onConflict: 'conversation_id,user_id',
    );
  }

  Future<void> archive(String conversationId, {required bool archived}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || conversationId.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('conversation_user_state').upsert(
      {
        'conversation_id': conversationId,
        'user_id': userId,
        'archived_at': archived ? now : null,
        'updated_at': now,
      },
      onConflict: 'conversation_id,user_id',
    );
  }
}
