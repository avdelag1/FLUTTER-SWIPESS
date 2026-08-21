import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AcceptedInterest {
  const AcceptedInterest({required this.conversationId, required this.matchId});

  final String conversationId;
  final String matchId;
}

/// Free mutual-interest path. Accepting an interest never consumes a token.
class InterestRepository {
  InterestRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchInterest(String likeId) async {
    final row = await _client
        .from('likes')
        .select('id,user_id,target_id,target_type,direction,created_at')
        .eq('id', likeId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<AcceptedInterest> accept(String likeId) async {
    final raw = await _client.rpc(
      'rpc_accept_interest',
      params: {'p_like_id': likeId},
    );
    final row = raw is List && raw.isNotEmpty ? raw.first : raw;
    if (row is! Map || row['conversation_id'] == null || row['match_id'] == null) {
      throw StateError('Could not create free match');
    }
    return AcceptedInterest(
      conversationId: row['conversation_id'].toString(),
      matchId: row['match_id'].toString(),
    );
  }
}

final interestRepositoryProvider = Provider<InterestRepository>((ref) {
  return InterestRepository();
});
