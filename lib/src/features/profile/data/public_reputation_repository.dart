import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/profile/domain/public_reputation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicReputationRepository {
  PublicReputationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<PublicReputation> fetch(String userId) async {
    final raw = await _client.rpc(
      'rpc_get_user_reputation',
      params: {'p_user_id': userId},
    );
    if (raw is Map) return PublicReputation.fromJson(raw);
    return PublicReputation(
      userId: userId,
      verified: false,
      reviewCount: 0,
      connections: 0,
    );
  }
}

final publicReputationRepositoryProvider = Provider<PublicReputationRepository>(
  (ref) => PublicReputationRepository(),
);

final publicReputationProvider = FutureProvider.family<PublicReputation, String>(
  (ref, userId) => ref.read(publicReputationRepositoryProvider).fetch(userId),
);
