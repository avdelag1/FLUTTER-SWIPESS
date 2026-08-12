import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

class DocumentRepository {
  DocumentRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<LegalDocument>> fetchMine() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final data = await _client
        .from('legal_documents')
        .select(
          'id, file_name, file_path, document_type, status, created_at, file_size, mime_type',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => LegalDocument.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> upload({
    required String fileName,
    required Uint8List bytes,
    required String documentType,
    String? mimeType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('Max 10MB');
    }
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}-$fileName';
    await _client.storage.from('legal-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? 'application/octet-stream',
            upsert: true,
          ),
        );
    await _client.from('legal_documents').insert({
      'user_id': userId,
      'file_name': fileName,
      'file_path': path,
      'mime_type': mimeType,
      'file_size': bytes.length,
      'document_type': documentType,
      'status': 'uploaded',
    });
  }

  Future<void> delete(LegalDocument doc) async {
    if (doc.filePath.isNotEmpty) {
      try {
        await _client.storage.from('legal-documents').remove([doc.filePath]);
      } catch (_) {}
    }
    await _client.from('legal_documents').delete().eq('id', doc.id);
  }

  Future<String> signedUrl(LegalDocument doc) async {
    final data = await _client.storage
        .from('legal-documents')
        .createSignedUrl(doc.filePath, 60);
    return data;
  }
}
