import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/camera/data/video_upload_optimizer.dart';

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  return ListingRepository();
});

/// Repository abstraction for listing data from Supabase.
/// Never call Supabase directly from the UI — always go through here.
class ListingRepository {
  final SupabaseClient _client;

  ListingRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const _swipeFields = '''
    id, title, description, price, images, video_url, video_original_url, video_hls_url,
    video_audio_enabled, background_music_url, background_music_preset,
    background_music_name, city, neighborhood, beds, baths, category,
    listing_type, property_type,
    amenities, pet_friendly, furnished, owner_id, created_at,
    updated_at, currency, latitude, longitude, status, is_active,
    has_verified_documents, verification_status, owner_verified_at
  ''';

  /// Fetch the swipe feed for the current user.
  ///
  /// A successful smart-feed response is authoritative even when it is empty.
  /// This is important: an empty result can mean every matching item has already
  /// been liked/passed, and must never trigger a direct-query resurrection.
  Future<List<Listing>> fetchSwipeFeed({
    String? category,
    String? interestType,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    int? minBaths,
    bool? furnished,
    bool? petFriendly,
    List<String> propertyTypes = const [],
    String? city,
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final data = await _client.rpc(
          'get_smart_listings',
          params: {
            'p_user_id': userId,
            'p_category': category ?? 'property',
            'p_limit': limit,
            'p_offset': offset,
          },
        );
        if (data is List) {
          final listings = data
              .whereType<Map>()
              .map((row) => Listing.fromJson(Map<String, dynamic>.from(row)))
              .where((listing) => listing.ownerId != userId)
              .toList();
          return _applyLocalFilters(
            listings,
            interestType: interestType,
            minPrice: minPrice,
            maxPrice: maxPrice,
            minBeds: minBeds,
            minBaths: minBaths,
            furnished: furnished,
            petFriendly: petFriendly,
            propertyTypes: propertyTypes,
            city: city,
          );
        }
      } catch (_) {
        // RPC unavailable: direct fallback below is still passed through the
        // server decision filter before anything reaches the UI.
      }
    }

    final direct = await _fetchDirect(
      category: category,
      interestType: interestType,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minBeds: minBeds,
      minBaths: minBaths,
      furnished: furnished,
      petFriendly: petFriendly,
      propertyTypes: propertyTypes,
      city: city,
      limit: limit,
      offset: offset,
    );
    return _filterDiscoverable(direct);
  }

  Future<List<Listing>> _filterDiscoverable(List<Listing> listings) async {
    if (listings.isEmpty || _client.auth.currentUser == null) return listings;
    try {
      final data = await _client.rpc(
        'rpc_filter_discoverable_listing_ids',
        params: {'p_ids': listings.map((e) => e.id).toList()},
      );
      if (data is! List) return const [];
      final visible = data.map((e) => e.toString()).toSet();
      final userId = _client.auth.currentUser?.id;
      return listings
          .where(
            (listing) =>
                visible.contains(listing.id) && listing.ownerId != userId,
          )
          .toList();
    } catch (_) {
      // Respecting a user's explicit pass/save is more important than showing
      // stale discovery content during a decision-service outage.
      return const [];
    }
  }

  Future<List<Listing>> _fetchDirect({
    String? category,
    String? interestType,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    int? minBaths,
    bool? furnished,
    bool? petFriendly,
    List<String> propertyTypes = const [],
    String? city,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('listings')
        .select(_swipeFields)
        .eq('is_active', true)
        .eq('status', 'active');

    final userId = _client.auth.currentUser?.id;
    if (userId != null) query = query.neq('owner_id', userId);

    if (category != null &&
        category.isNotEmpty &&
        category != 'all' &&
        category != 'recommended' &&
        category != 'popular') {
      query = query.eq('category', category);
    }
    if (interestType != null &&
        interestType.isNotEmpty &&
        interestType != 'both') {
      query = query.eq('listing_type', interestType);
    }
    if (minPrice != null) query = query.gte('price', minPrice);
    if (maxPrice != null) query = query.lte('price', maxPrice);
    if (minBeds != null && minBeds > 0) query = query.gte('beds', minBeds);
    if (minBaths != null && minBaths > 0) query = query.gte('baths', minBaths);
    if (furnished != null) query = query.eq('furnished', furnished);
    if (petFriendly != null) query = query.eq('pet_friendly', petFriendly);
    if (city != null && city.trim().isNotEmpty) {
      query = query.ilike('city', '%${city.trim()}%');
    }
    if (propertyTypes.isNotEmpty) {
      query = query.inFilter('property_type', propertyTypes);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  List<Listing> _applyLocalFilters(
    List<Listing> listings, {
    String? interestType,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    int? minBaths,
    bool? furnished,
    bool? petFriendly,
    List<String> propertyTypes = const [],
    String? city,
  }) {
    return listings.where((listing) {
      if (interestType != null &&
          interestType != 'both' &&
          listing.listingType != null &&
          listing.listingType != interestType) {
        return false;
      }
      if (minPrice != null && (listing.price ?? 0) < minPrice) return false;
      if (maxPrice != null && (listing.price ?? 0) > maxPrice) return false;
      final beds = listing.beds ?? listing.bedrooms ?? 0;
      if (minBeds != null && minBeds > 0 && beds < minBeds) return false;
      final baths = (listing.baths ?? listing.bathrooms ?? 0).ceil();
      if (minBaths != null && minBaths > 0 && baths < minBaths) return false;
      if (furnished != null && listing.furnished != furnished) return false;
      if (petFriendly != null && listing.petFriendly != petFriendly) {
        return false;
      }
      if (propertyTypes.isNotEmpty) {
        final pt = listing.propertyType;
        if (pt == null || !propertyTypes.contains(pt)) return false;
      }
      if (city != null && city.trim().isNotEmpty) {
        final c = (listing.city ?? '').toLowerCase();
        if (!c.contains(city.trim().toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  Future<Listing?> fetchById(String listingId) async {
    final data = await _client
        .from('listings')
        .select()
        .eq('id', listingId)
        .maybeSingle();
    if (data == null) return null;
    return Listing.fromJson(data);
  }

  Future<List<String>> uploadListingPhotos({
    required String userId,
    required List<XFile> files,
    Future<void> Function(String publicUrl)? moderateImage,
  }) async {
    if (files.isEmpty) return const <String>[];

    // Uploading and moderating every image serially made large property posts
    // painfully slow (20 photos could take 40+ seconds). Keep a small bounded
    // amount of parallelism so mobile uplinks stay stable while several images
    // move through Storage + moderation at the same time.
    const parallelism = 4;
    final urls = List<String?>.filled(files.length, null);
    final uploadStamp = DateTime.now().microsecondsSinceEpoch;

    for (var start = 0; start < files.length; start += parallelism) {
      final end = start + parallelism < files.length
          ? start + parallelism
          : files.length;

      await Future.wait<void>([
        for (var i = start; i < end; i++)
          () async {
            final file = files[i];
            final bytes = await file.readAsBytes();
            if (bytes.isEmpty) {
              throw Exception('One selected photo is empty.');
            }

            // Keep this aligned with the production listing-images bucket limit
            // so validation stays friendly instead of surfacing Storage errors.
            if (bytes.lengthInBytes > 10 * 1024 * 1024) {
              throw Exception('Each photo must be under 10MB.');
            }

            if (_isHeif(bytes)) {
              throw Exception(
                'One iPhone photo is still HEIC/HEIF and could not be converted. '
                'Open it in Photos, save/share it as JPEG, then choose it again.',
              );
            }

            final ext = _extensionForBytes(bytes, file.name);
            // One batch-wide microsecond stamp + the original index guarantees
            // unique paths even though several uploads start simultaneously.
            final path = '$userId/$uploadStamp-$i.$ext';
            await _client.storage
                .from('listing-images')
                .uploadBinary(
                  path,
                  bytes,
                  fileOptions: FileOptions(
                    contentType: _contentTypeFor(ext),
                    upsert: true,
                  ),
                );

            final url = _client.storage
                .from('listing-images')
                .getPublicUrl(path);
            if (moderateImage != null) {
              try {
                await moderateImage(url);
              } catch (_) {
                try {
                  await _client.storage.from('listing-images').remove([path]);
                } catch (_) {}
                rethrow;
              }
            }
            urls[i] = url;
          }(),
      ]);
    }

    return urls.whereType<String>().toList(growable: false);
  }

  Future<String> uploadListingVideo({
    required String userId,
    required XFile file,

    /// Existing listings upload under a listing-specific path so replacement
    /// clips stay clearly associated with the listing they belong to.
    String? listingId,
  }) async {
    // One delivery path for iOS, Android, PWA and web. Even if a caller skips
    // the editor, raw phone HEVC/MOV/4K media is normalized before it becomes a
    // public dashboard URL. Already-exported Swipess clips are passed through.
    final optimized = await optimizeVideoForUpload(file);
    final bytes = await optimized.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected video is empty. Please choose the clip again.');
    }
    if (bytes.lengthInBytes > 50 * 1024 * 1024) {
      throw Exception('Optimized video must be under 50MB.');
    }
    final lower = optimized.name.toLowerCase();
    final ext = lower.endsWith('.webm')
        ? 'webm'
        : lower.endsWith('.mov')
        ? 'mov'
        : 'mp4';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = listingId == null
        ? '$userId/$fileName'
        : '$userId/listing/$listingId/$fileName';
    final contentType = switch (ext) {
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      _ => 'video/mp4',
    };
    await _client.storage
        .from('listing-videos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: '31536000',
            upsert: true,
          ),
        );
    return _client.storage.from('listing-videos').getPublicUrl(path);
  }

  Future<String?> uploadListingAudio({
    required String userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Selected music file is empty.');
    if (bytes.lengthInBytes > 15 * 1024 * 1024) {
      throw Exception('Music file must be under 15MB.');
    }
    final lower = file.name.toLowerCase();
    final ext = lower.endsWith('.m4a')
        ? 'm4a'
        : lower.endsWith('.aac')
        ? 'aac'
        : lower.endsWith('.wav')
        ? 'wav'
        : lower.endsWith('.ogg')
        ? 'ogg'
        : 'mp3';
    final contentType = switch (ext) {
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'audio/mpeg',
    };
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('listing-audio')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from('listing-audio').getPublicUrl(path);
  }

  Future<void> uploadListingLegalDocuments({
    required String userId,
    required String listingId,
    required String category,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) return;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('One selected legal document is empty.');
      }
      if (bytes.lengthInBytes > 15 * 1024 * 1024) {
        throw Exception('Each legal document must be under 15MB.');
      }
      final safeName = _safeFileName(file.name);
      final contentType = _legalContentType(bytes, file.name, file.mimeType);
      final path =
          'listing-documents/$userId/$listingId/${DateTime.now().millisecondsSinceEpoch}-$i-$safeName';
      await _client.storage
          .from('legal-documents')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      await _client.from('listing_legal_documents').insert({
        'listing_id': listingId,
        'owner_id': userId,
        'file_name': file.name,
        'file_path': path,
        'mime_type': contentType,
        'file_size': bytes.lengthInBytes,
        'document_type': _listingLegalDocumentType(category, file.name),
        'status': 'pending',
      });
    }
    try {
      await _client
          .from('listings')
          .update({
            'verification_status': 'pending',
            'has_verified_documents': false,
          })
          .eq('id', listingId)
          .eq('owner_id', userId);
    } catch (_) {
      // Live schemas before the verification migration should not block publish.
    }
  }

  Future<Listing> createListing(Map<String, dynamic> payload) async {
    // Production listings are owned through owner_id. Older client payloads can
    // still contain the retired user_id key; strip it before the first insert so
    // publishing does not intentionally fail once before schema-retry recovers.
    final safe = Map<String, dynamic>.from(payload)..remove('user_id');
    final listing = await _saveWithSchemaRetry(safe, editingId: null);

    // Organic Social Boost is deliberately fire-and-forget. The server checks
    // explicit user opt-in + connected networks, and listing creation never
    // waits for Instagram/Facebook/TikTok/YouTube latency.
    unawaited(() async {
      try {
        await _client.functions.invoke(
          'social-distribute',
          body: {'listing_id': listing.id},
        );
      } catch (_) {}
    }());
    return listing;
  }

  Future<Listing> updateListing(
    String listingId,
    Map<String, dynamic> payload,
  ) {
    final safe = Map<String, dynamic>.from(payload)
      ..remove('user_id')
      ..remove('created_at');
    return _saveWithSchemaRetry(safe, editingId: listingId);
  }

  Future<Listing> _saveWithSchemaRetry(
    Map<String, dynamic> payload, {
    required String? editingId,
  }) async {
    var safe = Map<String, dynamic>.from(payload);
    final removed = <String>{};

    for (var attempt = 0; attempt < 25; attempt++) {
      try {
        final data = editingId == null
            ? await _client.from('listings').insert(safe).select().single()
            : await _client
                  .from('listings')
                  .update(safe)
                  .eq('id', editingId)
                  .select()
                  .single();
        return Listing.fromJson(data);
      } catch (error) {
        final message = error.toString();
        final missing = _missingColumn(message);
        if (missing == null ||
            !safe.containsKey(missing) ||
            removed.contains(missing)) {
          rethrow;
        }
        removed.add(missing);
        safe.remove(missing);
      }
    }
    throw Exception('Listing save failed after adapting to the live schema.');
  }

  Future<void> updateListingStatus({
    required String listingId,
    required String status,
  }) async {
    final active = status == 'active' || status == 'available';
    try {
      await _client
          .from('listings')
          .update({'status': status, 'is_active': active})
          .eq('id', listingId);
    } catch (_) {
      await _client
          .from('listings')
          .update({'status': status})
          .eq('id', listingId);
    }
  }

  Future<void> deleteListing(String listingId) async {
    await _client.from('listings').delete().eq('id', listingId);
  }

  Future<void> appendListingImages({
    required String listingId,
    required List<String> imageUrls,
  }) async {
    if (imageUrls.isEmpty) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');

    final row = await _client
        .from('listings')
        .select('images')
        .eq('id', listingId)
        .eq('owner_id', userId)
        .maybeSingle();
    if (row == null) throw StateError('Listing not found');

    final existing = <String>[];
    final raw = row['images'];
    if (raw is List) {
      existing.addAll(
        raw.map((e) => e.toString()).where((url) => url.trim().isNotEmpty),
      );
    }
    final merged = <String>{...existing, ...imageUrls}.toList(growable: false);

    // Production stores listing media in `images`; there is no `image_url`
    // column. The Listing model treats images.first as the canonical cover.
    await _client
        .from('listings')
        .update({'images': merged})
        .eq('id', listingId)
        .eq('owner_id', userId);
  }

  String _extensionForBytes(List<int> bytes, String name) {
    if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (_isWebp(bytes)) return 'webp';
    if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) return 'jpg';

    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  bool _startsWith(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  bool _isWebp(List<int> bytes) {
    if (bytes.length < 12) return false;
    return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
  }

  bool _isHeif(List<int> bytes) {
    if (bytes.length < 12) return false;
    if (String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') return false;
    final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
    return const {
      'heic',
      'heix',
      'hevc',
      'hevx',
      'heim',
      'heis',
      'mif1',
      'msf1',
    }.contains(brand);
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _legalContentType(List<int> bytes, String name, String? mimeType) {
    final mime = mimeType?.trim();
    if (mime != null && mime.isNotEmpty) return mime;
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf') ||
        _startsWith(bytes, const [0x25, 0x50, 0x44, 0x46])) {
      return 'application/pdf';
    }
    if (lower.endsWith('.png') ||
        _startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) {
      return 'image/png';
    }
    if (lower.endsWith('.webp') || _isWebp(bytes)) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif') || _isHeif(bytes)) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  String _listingLegalDocumentType(String category, String fileName) {
    final lower = fileName.toLowerCase();
    if (category == 'property') {
      if (lower.contains('fideicomiso') || lower.contains('trust')) {
        return 'fideicomiso';
      }
      if (lower.contains('lease') ||
          lower.contains('rental') ||
          lower.contains('contrato')) {
        return 'rental_agreement';
      }
      return 'ownership_deed';
    }
    if (category == 'yacht') return 'boat_registration';
    if (category == 'motorcycle') return 'vehicle_registration';
    if (category == 'worker') return 'professional_credential';
    return 'ownership_proof';
  }

  String _safeFileName(String name) {
    final trimmed = name.trim().isEmpty ? 'document' : name.trim();
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  String? _missingColumn(String message) {
    final quoted = RegExp(
      r'''['\"]([^'\"]+)['\"]\s+column|column\s+['\"]([^'\"]+)['\"]|find the ['\"]([^'\"]+)['\"] column''',
      caseSensitive: false,
    ).firstMatch(message);
    return quoted?.group(1) ?? quoted?.group(2) ?? quoted?.group(3);
  }
}
