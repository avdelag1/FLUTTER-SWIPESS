import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/profile/domain/maintenance_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository();
});

class MaintenanceRepository {
  MaintenanceRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<MaintenanceRequest>> fetchMine() async {
    final rows = await _client
        .from('maintenance_requests')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => MaintenanceRequest.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String title,
    required String description,
    String category = 'other',
    String priority = 'medium',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    await _client.from('maintenance_requests').insert({
      'tenant_id': userId,
      'owner_id': userId,
      'title': title,
      'description': description.isEmpty ? null : description,
      'category': category,
      'priority': priority,
      'status': 'submitted',
    });
  }
}
