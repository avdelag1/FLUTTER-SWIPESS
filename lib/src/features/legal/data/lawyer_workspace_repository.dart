import 'package:flutter_swipes/src/features/legal/domain/lawyer_workspace.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LawyerWorkspaceRepository {
  LawyerWorkspaceRepository(this._client);

  final SupabaseClient _client;

  Future<LawyerWorkspace> fetch() async {
    final result = await _client.rpc('app_lawyer_workspace');
    if (result is! Map) {
      throw StateError('Invalid lawyer workspace response');
    }
    return LawyerWorkspace.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> setAvailability(bool available) async {
    final result = await _client.rpc(
      'app_lawyer_set_availability',
      params: {'p_available': available},
    );
    if (result != true) {
      throw StateError('Could not update lawyer availability');
    }
  }
}
