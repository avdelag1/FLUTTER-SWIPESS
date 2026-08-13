import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalRepository {
  LegalRepository(this._client);
  final SupabaseClient _client;

  Future<List<LegalServicePackage>> fetchActivePackages() async {
    final response = await _client
        .from('legal_service_packages')
        .select()
        .eq('is_active', true)
        .order('category')
        .order('price');
        
    return (response as List<dynamic>)
        .map((e) => LegalServicePackage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitLegalCase({
    required String caseNumber,
    required String title,
    required String description,
    required String caseType,
    required String priority,
    required Map<String, dynamic> partiesInvolved,
  }) async {
    await _client.from('legal_cases').insert({
      'case_number': caseNumber,
      'title': title,
      'description': description,
      'case_type': caseType,
      'priority': priority,
      'status': 'open',
      'parties_involved': partiesInvolved,
    });
  }
}
