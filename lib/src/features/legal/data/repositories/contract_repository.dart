import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';

final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  return ContractRepository();
});

class ContractRepository {
  ContractRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<DigitalContract>> fetchMine() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final data = await _client
        .from('digital_contracts')
        .select()
        .or('owner_id.eq.$userId,client_id.eq.$userId')
        .order('updated_at', ascending: false);
    return (data as List)
        .map((row) => DigitalContract.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<DigitalContract> createFromTemplate(ContractTemplate template) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    final data = await _client.from('digital_contracts').insert({
      'title': template.name,
      'template_type': template.id,
      'content': template.content,
      'owner_id': userId,
      'client_id': userId,
      'status': 'draft',
    }).select().single();
    return DigitalContract.fromJson(data);
  }

  Future<DigitalContract> fetchById(String id) async {
    final data = await _client
        .from('digital_contracts')
        .select()
        .eq('id', id)
        .single();
    return DigitalContract.fromJson(data);
  }

  /// Finger-sign a contract the same way Capacitor LegalHub does:
  /// insert `contract_signatures`, then stamp owner/client signature columns.
  Future<void> sign({
    required DigitalContract contract,
    required String signatureData,
    String signatureType = 'drawn',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    await _client.from('contract_signatures').insert({
      'contract_id': contract.id,
      'signer_id': userId,
      'signature_data': signatureData,
      'signature_type': signatureType,
      'user_agent': 'flutter-swipes',
    });

    final isOwner = contract.ownerId == userId;
    final now = DateTime.now().toUtc().toIso8601String();
    final update = <String, dynamic>{
      if (isOwner) 'owner_signature': signatureData,
      if (isOwner) 'owner_signed_at': now,
      if (!isOwner) 'client_signature': signatureData,
      if (!isOwner) 'client_signed_at': now,
    };

    final otherAlreadySigned = isOwner
        ? contract.clientSignedAt != null
        : contract.ownerSignedAt != null;
    update['status'] = otherAlreadySigned || contract.clientId == contract.ownerId
        ? 'signed'
        : (isOwner ? 'signed_by_owner' : 'signed_by_client');

    try {
      await _client.from('digital_contracts').update(update).eq('id', contract.id);
    } catch (error) {
      // Live schema may not have signature columns — still keep status.
      await _client.from('digital_contracts').update({
        'status': update['status'],
      }).eq('id', contract.id);
    }
  }
}
