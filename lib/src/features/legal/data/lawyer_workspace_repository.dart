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

  Future<void> offerIntake({
    required String requestId,
    String? packageId,
    String? notes,
  }) async {
    await _client.rpc(
      'rpc_lawyer_offer_legal_intake',
      params: {
        'p_id': requestId,
        'p_package_id': packageId,
        'p_notes': notes,
      },
    );
  }

  Future<void> declineIntake({
    required String requestId,
    String? reason,
  }) async {
    await _client.rpc(
      'rpc_lawyer_decline_legal_intake',
      params: {'p_id': requestId, 'p_reason': reason},
    );
  }

  Future<void> scheduleConsult({
    required String requestId,
    required DateTime consultAt,
  }) async {
    await _client.rpc(
      'rpc_lawyer_schedule_legal_consult',
      params: {
        'p_id': requestId,
        'p_consult_at': consultAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<bool> updateWorkflow({
    required String requestId,
    required String status,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'update_legal_request_workflow',
      params: {
        'p_request_id': requestId,
        'p_status': status,
        'p_lawyer_notes': notes,
      },
    );
    return result == true;
  }
}
