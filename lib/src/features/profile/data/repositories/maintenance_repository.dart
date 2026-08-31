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
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _client
        .from('maintenance_requests')
        .select()
        .or('tenant_id.eq.$userId,owner_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(100)
        .timeout(const Duration(seconds: 8));
    return (rows as List)
        .map((row) => MaintenanceRequest.fromJson(row as Map<String, dynamic>))
        .toList();
  }

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
      if (bytes.isEmpty) continue;
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        throw Exception('Each maintenance photo must be under 10MB.');
      }
      final ext = _safeImageExtension(file.name);
      final path =
          'maintenance/$userId/${DateTime.now().millisecondsSinceEpoch}-$i.$ext';
      await _client.storage
          .from('listing-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _imageContentType(ext),
              upsert: true,
            ),
          )
          .timeout(const Duration(seconds: 15));
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
          .limit(1)
          .timeout(const Duration(seconds: 5));
      final rows = List<Map<String, dynamic>>.from(contracts as List);
      if (rows.isNotEmpty) {
        final row = rows.first;
        ownerId = row['owner_id'] as String? ?? userId;
        contractId = row['id'] as String?;
        listingId = row['listing_id'] as String?;
      }
    } catch (_) {
      // Maintenance must remain usable even without an active contract.
    }

    await _client
        .from('maintenance_requests')
        .insert({
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
        })
        .timeout(const Duration(seconds: 8));
  }

  String _safeImageExtension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _imageContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
