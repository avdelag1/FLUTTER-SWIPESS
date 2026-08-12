import 'package:cross_file/cross_file.dart';
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

  /// Cap MaintenanceRequestForm — photos to `listing-images`, link contract if any.
  Future<void> create({
    required String title,
    required String description,
    String category = 'other',
    String priority = 'medium',
    List<XFile> photos = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    final photoUrls = <String>[];
    for (var i = 0; i < photos.length && i < 5; i++) {
      final file = photos[i];
      final bytes = await file.readAsBytes();
      final path =
          'maintenance/$userId/${DateTime.now().millisecondsSinceEpoch}-$i.jpg';
      await _client.storage.from('listing-images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      photoUrls.add(_client.storage.from('listing-images').getPublicUrl(path));
    }

    String? ownerId = userId;
    String? contractId;
    String? listingId;
    try {
      final contracts = await _client
          .from('digital_contracts')
          .select('id, owner_id, listing_id')
          .eq('client_id', userId)
          .eq('status', 'active')
          .limit(1);
      final rows = List<Map<String, dynamic>>.from(contracts as List);
      if (rows.isNotEmpty) {
        final row = rows.first;
        ownerId = row['owner_id'] as String? ?? userId;
        contractId = row['id'] as String?;
        listingId = row['listing_id'] as String?;
      }
    } catch (_) {
      // Contracts table may be unavailable — still submit the request.
    }

    await _client.from('maintenance_requests').insert({
      'tenant_id': userId,
      'owner_id': ownerId,
      'contract_id': contractId,
      'listing_id': listingId,
      'title': title,
      'description': description.isEmpty ? null : description,
      'category': category,
      'priority': priority,
      'photo_urls': photoUrls,
      'status': 'submitted',
    });
  }
}
