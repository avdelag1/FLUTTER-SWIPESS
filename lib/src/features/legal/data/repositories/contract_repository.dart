import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/legal/domain/contract_templates.dart';
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
    final data = await _client
        .from('digital_contracts')
        .insert({
          // contract_type remains a required legacy column in production.
          // Keep it meaningful while template_type identifies the exact builder.
          'contract_type': template.category,
          'title': template.name,
          'template_type': template.id,
          'content': template.content,
          'terms_and_conditions': template.content,
          'owner_id': userId,
          'client_id': userId,
          'created_by': userId,
          'status': 'draft',
          'metadata': {
            'template_category': template.category,
            'for_role': template.forRole,
          },
        })
        .select()
        .single();
    return DigitalContract.fromJson(data);
  }

  Future<DigitalContract> duplicate(DigitalContract contract) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    final data = await _client
        .from('digital_contracts')
        .insert({
          'contract_type':
              contract.metadata['template_category']?.toString() ?? 'agreement',
          'title': '${contract.title} — Copy',
          'template_type': contract.templateType,
          'content': contract.content ?? '',
          'terms_and_conditions': contract.content ?? '',
          'owner_id': userId,
          'client_id': userId,
          'created_by': userId,
          'status': 'draft',
          'metadata': {...contract.metadata, 'duplicated_from': contract.id},
        })
        .select()
        .single();
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

  Future<DigitalContract> saveDraft({
    required String contractId,
    required String title,
    required String content,
    Map<String, dynamic> metadata = const {},
  }) async {
    final data = await _client.rpc(
      'rpc_update_contract_draft',
      params: {
        'p_contract_id': contractId,
        'p_title': title,
        'p_content': content,
        'p_metadata': metadata,
      },
    );
    return _fromRpc(data);
  }

  Future<List<ContractPartyMatch>> resolveCounterparty(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final data = await _client.rpc(
      'rpc_resolve_contract_counterparty',
      params: {'p_query': trimmed},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (row) => ContractPartyMatch.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<DigitalContract> sendForSignature({
    required String contractId,
    required String clientId,
  }) async {
    final data = await _client.rpc(
      'rpc_share_contract_with_user',
      params: {'p_contract_id': contractId, 'p_client_id': clientId},
    );
    return _fromRpc(data);
  }

  Future<DigitalContract> sign({
    required DigitalContract contract,
    required String signatureData,
    String signatureType = 'drawn',
  }) async {
    final data = await _client.rpc(
      'rpc_sign_contract',
      params: {
        'p_contract_id': contract.id,
        'p_signature_data': signatureData,
        'p_signature_type': signatureType,
        'p_user_agent': 'flutter-swipess',
      },
    );
    return _fromRpc(data);
  }

  Future<DigitalContract> cancel(String contractId) async {
    final data = await _client.rpc(
      'rpc_cancel_contract',
      params: {'p_contract_id': contractId},
    );
    return _fromRpc(data);
  }

  Future<List<ContractEvent>> fetchEvents(String contractId) async {
    final data = await _client
        .from('contract_events')
        .select()
        .eq('contract_id', contractId)
        .order('created_at', ascending: false);
    return (data as List)
        .whereType<Map>()
        .map((row) => ContractEvent.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  DigitalContract _fromRpc(dynamic data) {
    if (data is Map) {
      return DigitalContract.fromJson(Map<String, dynamic>.from(data));
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return DigitalContract.fromJson(
        Map<String, dynamic>.from(data.first as Map),
      );
    }
    throw Exception('Unexpected contract response');
  }
}
