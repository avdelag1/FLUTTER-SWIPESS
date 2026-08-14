import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/admin/domain/admin_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

/// Cap admin pages — RPCs and tables stay behind this repository.
class AdminRepository {
  AdminRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _uploads = 'admin-uploads';

  Future<bool> hasAdminRole() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final data = await _client.rpc(
        'has_role',
        params: {'_user_id': uid, '_role': 'admin'},
      );
      return data == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<AdminEventRow>> fetchEvents() async {
    Future<List<AdminEventRow>> run(String select) async {
      final rows = await _client
          .from('events')
          .select(select)
          .order('created_at', ascending: false)
          .limit(200);
      return [
        for (final row in rows as List)
          if (row is Map)
            AdminEventRow.fromJson(Map<String, dynamic>.from(row)),
      ];
    }

    try {
      return await run(
        'id, title, category, image_url, event_date, location, is_published, is_approved, organizer_name, organizer_whatsapp, organizer_instagram, organizer_website, organizer_facebook',
      );
    } catch (_) {
      return run(
        'id, title, category, image_url, event_date, location, is_published, is_approved, organizer_name, organizer_whatsapp',
      );
    }
  }

  Future<List<PromoSubmission>> fetchSubmissions() async {
    try {
      final rows = await _client
          .from('business_promo_submissions')
          .select(
            'id, user_id, title, description, event_type, location, contact_name, contact_phone, status, created_at, website, image_url, video_url',
          )
          .order('created_at', ascending: false)
          .limit(200);
      return [
        for (final row in rows as List)
          if (row is Map)
            PromoSubmission.fromJson(Map<String, dynamic>.from(row)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsertEvent(AdminEventDraft draft, {String? editingId}) async {
    final uid = _client.auth.currentUser?.id;
    final createdBy = editingId == null ? uid : null;
    try {
      await _writeEvent(
        draft.toPayload(createdBy: createdBy),
        editingId: editingId,
      );
    } catch (_) {
      await _writeEvent(
        draft.toPayload(createdBy: createdBy, includeSocials: false),
        editingId: editingId,
      );
    }
  }

  Future<void> _writeEvent(
    Map<String, dynamic> payload, {
    String? editingId,
  }) async {
    if (editingId != null) {
      await _client.from('events').update(payload).eq('id', editingId);
    } else {
      await _client.from('events').insert(payload);
    }
  }

  Future<void> deleteEvent(String id) async {
    await _client.from('events').delete().eq('id', id);
  }

  Future<void> togglePublished(String id, bool currentlyPublished) async {
    await _client
        .from('events')
        .update({'is_published': !currentlyPublished}).eq('id', id);
  }

  Future<void> approveSubmission(PromoSubmission sub) async {
    final payload = <String, dynamic>{
      'title': sub.title,
      'description': sub.description,
      'category': sub.eventType ?? 'promo',
      'image_url': sub.imageUrl,
      'video_url': sub.videoUrl,
      'location': sub.location,
      'organizer_name': sub.contactName,
      'organizer_whatsapp': sub.contactPhone,
      'organizer_website': sub.website,
      'is_approved': true,
      'is_published': true,
      'created_by': sub.userId,
    };
    try {
      await _client.from('events').insert(payload);
    } catch (_) {
      payload.remove('organizer_website');
      try {
        await _client.from('events').insert(payload);
      } catch (_) {
        payload.remove('video_url');
        await _client.from('events').insert(payload);
      }
    }
    await _client
        .from('business_promo_submissions')
        .update({'status': 'approved'}).eq('id', sub.id);
    if (sub.userId != null) {
      try {
        await _client.rpc(
          'create_notification_for_user',
          params: {
            'p_user_id': sub.userId,
            'p_notification_type': 'system_announcement',
            'p_title': 'Your event is live! 🎉',
            'p_message':
                '"${sub.title}" was approved and is now featured in the Events feed.',
          },
        );
      } catch (_) {}
    }
  }

  Future<void> rejectSubmission(PromoSubmission sub) async {
    await _client
        .from('business_promo_submissions')
        .update({'status': 'rejected'}).eq('id', sub.id);
    if (sub.userId != null) {
      try {
        await _client.rpc(
          'create_notification_for_user',
          params: {
            'p_user_id': sub.userId,
            'p_notification_type': 'system_announcement',
            'p_title': 'Event submission update',
            'p_message':
                '"${sub.title}" wasn\'t approved this time. You can edit and resubmit it from the Advertise page.',
          },
        );
      } catch (_) {}
    }
  }

  Future<String> uploadEventImage(XFile file) async {
    final uid = _client.auth.currentUser?.id ?? 'anon';
    final ext = file.name.split('.').last;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage.from('event-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg'),
        );
    return _client.storage.from('event-images').getPublicUrl(path);
  }

  Future<List<AdminPhoto>> listPhotos(String folder) async {
    const folders = {
      'all': [''],
      'ai-mock': ['ai-mock/'],
      'real': ['real/'],
      'promote': ['promote/'],
    };
    final collected = <AdminPhoto>[];
    Future<void> listAt(String prefix) async {
      final files = await _client.storage.from(_uploads).list(
            path: prefix.isEmpty ? null : prefix.replaceAll(RegExp(r'/$'), ''),
          );
      for (final f in files) {
        if (f.name.startsWith('.')) continue;
        final full = prefix.isEmpty ? f.name : '$prefix${f.name}';
        if (f.id == null && prefix.isEmpty) continue;
        collected.add(
          AdminPhoto(
            name: full,
            publicUrl: _client.storage.from(_uploads).getPublicUrl(full),
            size: (f.metadata?['size'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }

    if (folder == 'category') {
      final roots = await _client.storage.from(_uploads).list();
      for (final r in roots) {
        if (r.name.startsWith('category-')) {
          await listAt('${r.name}/');
        }
      }
    } else if (folder == 'all') {
      await listAt('');
      for (final p in ['ai-mock/', 'real/', 'promote/']) {
        await listAt(p);
      }
    } else {
      for (final p in folders[folder] ?? ['']) {
        await listAt(p);
      }
    }
    return collected;
  }

  Future<String> uploadAdminPhoto(XFile file, String folder) async {
    final prefix = switch (folder) {
      'ai-mock' => 'ai-mock/',
      'real' => 'real/',
      'promote' => 'promote/',
      _ => 'real/',
    };
    final ext = file.name.split('.').last;
    final path = '$prefix${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage.from(_uploads).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg'),
        );
    return _client.storage.from(_uploads).getPublicUrl(path);
  }

  Future<void> deletePhoto(String name) async {
    await _client.storage.from(_uploads).remove([name]);
  }

  Future<List<CategoryPhoto>> fetchCategoryPhotos(String categoryId) async {
    try {
      final rows = await _client
          .from('category_photos')
          .select('id, category_id, image_url, sort_order')
          .eq('category_id', categoryId)
          .order('sort_order', ascending: true);
      return [
        for (final row in rows as List)
          if (row is Map)
            CategoryPhoto.fromJson(Map<String, dynamic>.from(row)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> uploadCategoryPhoto({
    required String categoryId,
    required XFile file,
    required int sortOrder,
  }) async {
    final ext = file.name.split('.').last;
    final path =
        'category-$categoryId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage.from(_uploads).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg'),
        );
    final url = _client.storage.from(_uploads).getPublicUrl(path);
    await _client.from('category_photos').insert({
      'category_id': categoryId,
      'image_url': url,
      'sort_order': sortOrder,
    });
  }

  Future<void> deleteCategoryPhoto(String id) async {
    await _client.from('category_photos').delete().eq('id', id);
  }
}
