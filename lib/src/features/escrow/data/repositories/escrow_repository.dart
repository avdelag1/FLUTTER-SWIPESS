import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/escrow/domain/escrow_deposit.dart';

final escrowRepositoryProvider = Provider<EscrowRepository>((ref) {
  return EscrowRepository();
});

class EscrowRepository {
  EscrowRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<EscrowDeposit>> fetchMine() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final data = await _client
        .from('escrow_deposits')
        .select()
        .or('client_id.eq.$userId,owner_id.eq.$userId')
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => EscrowDeposit.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateStatus(String id, String status) async {
    final patch = <String, dynamic>{
      'status': status,
      if (status == 'held') 'held_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'released')
        'released_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'disputed')
        'disputed_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from('escrow_deposits').update(patch).eq('id', id);
  }
}
