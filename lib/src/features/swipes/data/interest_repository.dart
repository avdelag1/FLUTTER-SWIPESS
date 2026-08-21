import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AcceptedInterest {
  const AcceptedInterest({
    required this.conversationId,
    required this.matchId,
    required this.interestedUserId,
  });

  final String conversationId;
  final String matchId;
  final String interestedUserId;
}

/// Free mutual-interest path. Accepting an interest never consumes a token.
/// All cross-user reads and writes stay inside the owner-authorized RPC.
class InterestRepository {
  InterestRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AcceptedInterest> accept(String likeId) async {
    final raw = await _client.rpc(
      'rpc_accept_interest',
      params: {'p_like_id': likeId},
    );
    final row = raw is List && raw.isNotEmpty ? raw.first : raw;
    if (row is! Map ||
        row['conversation_id'] == null ||
        row['match_id'] == null ||
        row['interested_user_id'] == null) {
      throw StateError('Could not create free match');
    }
    return AcceptedInterest(
      conversationId: row['conversation_id'].toString(),
      matchId: row['match_id'].toString(),
      interestedUserId: row['interested_user_id'].toString(),
    );
  }
}

final interestRepositoryProvider = Provider<InterestRepository>((ref) {
  return InterestRepository();
});
