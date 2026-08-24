import 'package:flutter_swipes/src/features/business/domain/business_workspace.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessWorkspaceRepository {
  BusinessWorkspaceRepository(this._client);

  final SupabaseClient _client;

  Future<BusinessWorkspace> fetch() async {
    final result = await _client.rpc('app_business_workspace');
    if (result is! Map) {
      throw StateError('Invalid business workspace response');
    }
    return BusinessWorkspace.fromJson(Map<String, dynamic>.from(result));
  }
}
