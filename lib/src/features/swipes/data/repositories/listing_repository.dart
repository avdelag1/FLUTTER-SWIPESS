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
    id, title, description, price, images, video_url, video_original_url,
    video_playback_url, video_poster_url, video_hls_url, video_processing_status,
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

  Future<List<String>> uploadListingPhotos({
    required String userId,
    required List<XFile> files,
    Future<void> Function(XFile file)? moderateImage,
  }) async {
    if (files.isEmpty) return const [];
    final urls = List<String?>.filled(files.length, null);
    const concurrency = 6;
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= files.length) return;
        final file = files[index];
        if (moderateImage != null) {
          try {
            await moderateImage(file);
          } catch (_) {
            // Moderation rejection removes this one photo only. A 20-photo
            // listing must not be destroyed because one image failed review.
            continue;
          }
        }
        final bytes = await file.readAsBytes();
        final ext = _extensionForBytes(bytes, file.name);
        final path = '$userId/${DateTime.now().microsecondsSinceEpoch}_$index.$ext';
        await _client.storage.from('listing-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(ext), upsert: false),
        );
        urls[index] = _client.storage.from('listing-images').getPublicUrl(path);
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
    final approved = urls.whereType<String>().toList(growable: false);
    if (approved.isEmpty) {
      throw StateError('No photos passed safety review.');
    }
    return approved;
  }

  Future<String> uploadListingVideo({
    required String userId,
    required XFile file,
  }) async {
    final optimized = await optimizeVideoForUpload(file);
    final bytes = await optimized.readAsBytes();
    final lower = optimized.name.toLowerCase();
    final ext = lower.endsWith('.mov')
        ? 'mov'
        : lower.endsWith('.webm')
        ? 'webm'
        : lower.endsWith('.m4v')
        ? 'm4v'
        : 'mp4';
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _client.storage.from('listing-videos').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: 'video/$ext', upsert: false),
    );
    return _client.storage.from('listing-videos').getPublicUrl(path);
  }

  Future<String> uploadListingAudio({
    required String userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final lower = file.name.toLowerCase();
    final ext = lower.endsWith('.m4a')
        ? 'm4a'
        : lower.endsWith('.wav')
        ? 'wav'
        : 'mp3';
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _client.storage.from('listing-audio').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: 'audio/$ext', upsert: false),
    );
    return _client.storage.from('listing-audio').getPublicUrl(path);
  }

  Future<Listing> createListing(Map<String, dynamic> payload) async {
    final row = await _client.from('listings').insert(payload).select().single();
    return Listing.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateListingStatus({
    required String listingId,
    required String status,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');

    final active = status == 'active' || status == 'available';
    final rows = await _client
        .from('listings')
        .update({'status': status, 'is_active': active})
        .eq('id', listingId)
        .eq('owner_id', userId)
        .select('id, status, is_active');

    if (rows is! List || rows.isEmpty) {
      throw StateError('Listing status was not changed. Refresh and try again.');
    }

    final row = Map<String, dynamic>.from(rows.first as Map);
    final serverStatus = row['status']?.toString();
    final serverActive = row['is_active'] == true;
    if (serverStatus != status || serverActive != active) {
      throw StateError('Listing status did not save correctly. Please retry.');
    }
  }

  Future<void> deleteListing(String listingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');

    // Never report a successful delete just because PostgREST returned 204.
    // Returning the deleted row proves both ownership and that the database
    // mutation really happened. A zero-row response is treated as an error so
    // the UI cannot hide a card that still exists on the server.
    final rows = await _client
        .from('listings')
        .delete()
        .eq('id', listingId)
        .eq('owner_id', userId)
        .select('id');

    if (rows is! List || rows.isEmpty) {
      final stillThere = await _client
          .from('listings')
          .select('id')
          .eq('id', listingId)
          .eq('owner_id', userId)
          .maybeSingle();
      if (stillThere != null) {
        throw StateError('Listing could not be deleted. Refresh and try again.');
      }
    }
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
      if (lower.contains('deed') || lower.contains('escritura')) {
        return 'property_deed';
      }
      return 'property_document';
    }
    if (category == 'motorcycle' ||
        category == 'bicycle' ||
        category == 'yacht') {
      if (lower.contains('registration') || lower.contains('circulacion')) {
        return 'vehicle_registration';
      }
      return 'vehicle_document';
    }
    return 'identity_document';
  }

  Future<List<Map<String, dynamic>>> uploadListingLegalDocuments({
    required String userId,
    required String listingId,
    required String category,
    required List<XFile> files,
  }) async {
    final uploaded = <Map<String, dynamic>>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await file.readAsBytes();
      final lower = file.name.toLowerCase();
      final ext = lower.contains('.') ? lower.split('.').last : 'bin';
      final path = '$userId/$listingId/${DateTime.now().microsecondsSinceEpoch}_$i.$ext';
      await _client.storage.from('listing-legal-documents').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: _legalContentType(bytes, file.name, file.mimeType),
          upsert: false,
        ),
      );
      final publicUrl = _client.storage
          .from('listing-legal-documents')
          .getPublicUrl(path);
      final documentType = _listingLegalDocumentType(category, file.name);
      final row = await _client
          .from('listing_verification_documents')
          .insert({
            'listing_id': listingId,
            'owner_id': userId,
            'document_type': documentType,
            'file_url': publicUrl,
            'file_name': file.name,
            'mime_type': _legalContentType(bytes, file.name, file.mimeType),
            'status': 'pending',
          })
          .select()
          .single();
      uploaded.add(Map<String, dynamic>.from(row));
    }
    return uploaded;
  }
}
