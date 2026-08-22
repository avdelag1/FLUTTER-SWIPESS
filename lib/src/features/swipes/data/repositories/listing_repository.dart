import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

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
    id, title, description, price, previous_price, images, video_url,
    city, neighborhood, beds, baths, square_footage, category,
    listing_type, property_type, vehicle_brand, vehicle_model, year,
    mileage, amenities, pet_friendly, furnished, owner_id, created_at,
    updated_at, currency, pricing_unit, service_category, experience_years,
    experience_level, latitude, longitude, status, is_active, hourly_rate
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
      return listings.where((listing) => visible.contains(listing.id)).toList();
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
    if (propertyTypes.isNotEmpty) query = query.inFilter('property_type', propertyTypes);

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
      if (petFriendly != null && listing.petFriendly != petFriendly) return false;
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
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('One selected photo is empty.');
      if (bytes.lengthInBytes > 20 * 1024 * 1024) {
        throw Exception('Each photo must be under 20MB.');
      }

      // image_picker is asked to re-encode gallery images before this point.
      // Check the actual bytes anyway so a raw HEIC/HEIF file can never be
      // uploaded with a fake .jpg extension and then fail in browsers/cards.
      if (_isHeif(bytes)) {
        throw Exception(
          'One iPhone photo is still HEIC/HEIF and could not be converted. '
          'Open it in Photos, save/share it as JPEG, then choose it again.',
        );
      }

      final ext = _extensionForBytes(bytes, file.name);
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}-$i.$ext';
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
      final url = _client.storage.from('listing-images').getPublicUrl(path);
      if (moderateImage != null) {
        try {
          await moderateImage(url);
        } catch (e) {
          try {
            await _client.storage.from('listing-images').remove([path]);
          } catch (_) {}
          rethrow;
        }
      }
      urls.add(url);
    }
    return urls;
  }

  Future<String?> uploadListingVideo({
    required String userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 50 * 1024 * 1024) {
      throw Exception('Video must be under 50MB.');
    }
    final lower = file.name.toLowerCase();
    final ext = lower.endsWith('.webm')
        ? 'webm'
        : lower.endsWith('.mov')
        ? 'mov'
        : 'mp4';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
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
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from('listing-videos').getPublicUrl(path);
  }

  Future<Listing> createListing(Map<String, dynamic> payload) async {
    return _saveWithSchemaRetry(payload, editingId: null);
  }

  Future<Listing> updateListing(
    String listingId,
    Map<String, dynamic> payload,
  ) {
    final safe = Map<String, dynamic>.from(payload)..remove('user_id');
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
    final row = await _client
        .from('listings')
        .select('images')
        .eq('id', listingId)
        .maybeSingle();
    final existing = <String>[];
    final raw = row?['images'];
    if (raw is List) existing.addAll(raw.map((e) => e.toString()));
    final merged = [...existing, ...imageUrls];
    await _client
        .from('listings')
        .update({
          'images': merged,
          'image_url': merged.isNotEmpty ? merged.first : null,
        })
        .eq('id', listingId);
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

  String? _missingColumn(String message) {
    final quoted = RegExp(
      r'''['"]([^'"]+)['"]\s+column|column\s+['"]([^'"]+)['"]|find the ['"]([^'"]+)['"] column''',
      caseSensitive: false,
    ).firstMatch(message);
    return quoted?.group(1) ?? quoted?.group(2) ?? quoted?.group(3);
  }
}
