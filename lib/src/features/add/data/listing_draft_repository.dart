import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavedListingDraft {
  const SavedListingDraft({
    required this.id,
    required this.draftKey,
    required this.kind,
    required this.category,
    required this.step,
    required this.payload,
    required this.updatedAt,
    this.sourceListingId,
    this.photos = const [],
    this.video,
    this.documents = const [],
    this.backgroundMusic,
  });

  final String id;
  final String draftKey;
  final String kind;
  final String category;
  final int step;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
  final String? sourceListingId;
  final List<XFile> photos;
  final XFile? video;
  final List<XFile> documents;
  final XFile? backgroundMusic;
}

class ListingDraftRepository {
  ListingDraftRepository(this._client);

  static const _bucket = 'listing-drafts';
  final SupabaseClient _client;

  Future<SavedListingDraft?> load(String draftKey) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('listing_drafts')
        .select()
        .eq('user_id', user.id)
        .eq('draft_key', draftKey)
        .maybeSingle();
    if (row == null) return null;

    final media = _map(row['media']);
    final photos = await _downloadMany(_mediaList(media['photos']));
    final documents = await _downloadMany(_mediaList(media['documents']));
    final videoEntry = _mediaEntry(media['video']);
    final musicEntry = _mediaEntry(media['background_music']);

    return SavedListingDraft(
      id: row['id'].toString(),
      draftKey: row['draft_key'].toString(),
      kind: row['kind'].toString(),
      category: row['category'].toString(),
      sourceListingId: row['source_listing_id']?.toString(),
      step: _int(row['step']),
      payload: _map(row['payload']),
      photos: photos,
      video: videoEntry == null ? null : await _downloadOne(videoEntry),
      documents: documents,
      backgroundMusic: musicEntry == null
          ? null
          : await _downloadOne(musicEntry),
      updatedAt:
          DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Future<void> save({
    required String draftKey,
    required String kind,
    required String category,
    required int step,
    required Map<String, dynamic> payload,
    String? sourceListingId,
    List<XFile> photos = const [],
    XFile? video,
    List<XFile> documents = const [],
    XFile? backgroundMusic,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in required to save a draft.');

    final existing = await _client
        .from('listing_drafts')
        .select('id, media')
        .eq('user_id', user.id)
        .eq('draft_key', draftKey)
        .maybeSingle();

    final String draftId;
    final oldMedia = _map(existing?['media']);
    if (existing == null) {
      final row = await _client
          .from('listing_drafts')
          .insert({
            'user_id': user.id,
            'draft_key': draftKey,
            'kind': kind,
            'category': category,
            'source_listing_id': sourceListingId,
            'step': step,
            'payload': payload,
            'media': const <String, dynamic>{},
          })
          .select('id')
          .single();
      draftId = row['id'].toString();
    } else {
      draftId = existing['id'].toString();
    }

    final version = DateTime.now().microsecondsSinceEpoch.toString();
    final uploadedPaths = <String>[];
    try {
      final photoEntries = await _uploadMany(
        userId: user.id,
        draftId: draftId,
        version: version,
        section: 'photos',
        files: photos,
        uploadedPaths: uploadedPaths,
      );
      final documentEntries = await _uploadMany(
        userId: user.id,
        draftId: draftId,
        version: version,
        section: 'documents',
        files: documents,
        uploadedPaths: uploadedPaths,
      );
      final videoEntry = video == null
          ? null
          : await _uploadOne(
              userId: user.id,
              draftId: draftId,
              version: version,
              section: 'video',
              index: 0,
              file: video,
              uploadedPaths: uploadedPaths,
            );
      final musicEntry = backgroundMusic == null
          ? null
          : await _uploadOne(
              userId: user.id,
              draftId: draftId,
              version: version,
              section: 'music',
              index: 0,
              file: backgroundMusic,
              uploadedPaths: uploadedPaths,
            );

      final media = <String, dynamic>{
        'photos': photoEntries,
        'documents': documentEntries,
        'video': videoEntry,
        'background_music': musicEntry,
      };

      await _client
          .from('listing_drafts')
          .update({
            'kind': kind,
            'category': category,
            'source_listing_id': sourceListingId,
            'step': step,
            'payload': payload,
            'media': media,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', draftId)
          .eq('user_id', user.id);

      final oldPaths = _allMediaPaths(oldMedia)
          .where((path) => !uploadedPaths.contains(path))
          .toList(growable: false);
      if (oldPaths.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(oldPaths);
        } catch (_) {
          // The row already points at the new atomic media snapshot. Orphan
          // cleanup is best-effort and must never make a saved draft look lost.
        }
      }
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(uploadedPaths);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> delete(String draftKey) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final row = await _client
        .from('listing_drafts')
        .select('id, media')
        .eq('user_id', user.id)
        .eq('draft_key', draftKey)
        .maybeSingle();
    if (row == null) return;

    await _client
        .from('listing_drafts')
        .delete()
        .eq('id', row['id'])
        .eq('user_id', user.id);
    final paths = _allMediaPaths(_map(row['media']));
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(_bucket).remove(paths);
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> _uploadMany({
    required String userId,
    required String draftId,
    required String version,
    required String section,
    required List<XFile> files,
    required List<String> uploadedPaths,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var index = 0; index < files.length; index++) {
      result.add(
        await _uploadOne(
          userId: userId,
          draftId: draftId,
          version: version,
          section: section,
          index: index,
          file: files[index],
          uploadedPaths: uploadedPaths,
        ),
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> _uploadOne({
    required String userId,
    required String draftId,
    required String version,
    required String section,
    required int index,
    required XFile file,
    required List<String> uploadedPaths,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('One draft media file is empty.');
    if (bytes.lengthInBytes > 60 * 1024 * 1024) {
      throw StateError('Each draft media file must be under 60MB.');
    }
    final safeName = _safeName(file.name.isEmpty ? 'media-$index' : file.name);
    final path = '$userId/$draftId/$version/$section/$index-$safeName';
    final mimeType = _mimeType(file);
    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );
    uploadedPaths.add(path);
    return <String, dynamic>{
      'path': path,
      'name': file.name.isEmpty ? safeName : file.name,
      'mime_type': mimeType,
      'size': bytes.lengthInBytes,
    };
  }

  Future<List<XFile>> _downloadMany(List<Map<String, dynamic>> entries) async {
    final result = <XFile>[];
    for (final entry in entries) {
      result.add(await _downloadOne(entry));
    }
    return result;
  }

  Future<XFile> _downloadOne(Map<String, dynamic> entry) async {
    final path = entry['path']?.toString() ?? '';
    if (path.isEmpty) throw StateError('Draft media path is missing.');
    final name = entry['name']?.toString().trim();
    final safeName = _safeName(
      name == null || name.isEmpty ? path.split('/').last : name,
    );
    final mimeType = entry['mime_type']?.toString();
    final bytes = await _client.storage.from(_bucket).download(path);

    if (kIsWeb) {
      return XFile.fromData(
        bytes,
        name: safeName,
        mimeType: mimeType,
        length: bytes.lengthInBytes,
      );
    }

    final directory = await Directory.systemTemp.createTemp('swipess-draft-');
    final file = File('${directory.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, name: safeName, mimeType: mimeType);
  }

  List<String> _allMediaPaths(Map<String, dynamic> media) {
    final paths = <String>[];
    for (final key in const [
      'photos',
      'documents',
    ]) {
      for (final entry in _mediaList(media[key])) {
        final path = entry['path']?.toString();
        if (path != null && path.isNotEmpty) paths.add(path);
      }
    }
    for (final key in const ['video', 'background_music']) {
      final entry = _mediaEntry(media[key]);
      final path = entry?['path']?.toString();
      if (path != null && path.isNotEmpty) paths.add(path);
    }
    return paths;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mediaList(Object? value) {
    if (value is! List) return const [];
    return value.map(_map).toList(growable: false);
  }

  static Map<String, dynamic>? _mediaEntry(Object? value) {
    final entry = _map(value);
    return entry.isEmpty ? null : entry;
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _safeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return cleaned.isEmpty ? 'media.bin' : cleaned;
  }

  static String _mimeType(XFile file) {
    final explicit = file.mimeType?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}

final listingDraftRepositoryProvider = Provider<ListingDraftRepository>((ref) {
  return ListingDraftRepository(Supabase.instance.client);
});
