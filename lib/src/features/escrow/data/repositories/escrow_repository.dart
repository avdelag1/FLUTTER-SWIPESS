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

  /// Create a security deposit linked to an optional contract.
  Future<EscrowDeposit> createDeposit({
    required double amount,
    required String counterpartyId,
    String currency = 'USD',
    String? contractId,
    String? notes,
    bool asOwner = true,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    final row = await _client.from('escrow_deposits').insert({
      'amount': amount,
      'currency': currency,
      'status': 'pending',
      'contract_id': contractId,
      'notes': notes,
      'owner_id': asOwner ? userId : counterpartyId,
      'client_id': asOwner ? counterpartyId : userId,
    }).select().single();
    return EscrowDeposit.fromJson(row);
  }
}
