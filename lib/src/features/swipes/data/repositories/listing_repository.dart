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

  /// Swipe card fields — matches web app's SWIPE_CARD_FIELDS.
  static const _swipeFields = '''
    id, title, description, price, previous_price, images, video_url,
    city, neighborhood, beds, baths, square_footage, category,
    listing_type, property_type, vehicle_brand, vehicle_model, year,
    mileage, amenities, pet_friendly, furnished, owner_id, created_at,
    updated_at, currency, pricing_unit, service_category, experience_years,
    experience_level, latitude, longitude, status, is_active
  ''';

  /// Fetch the swipe feed for the current user.
  ///
  /// Tries the RPC function first (which excludes already-swiped listings),
  /// falls back to a direct query if the RPC doesn't exist yet.
  Future<List<Listing>> fetchSwipeFeed({
    String? category,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    bool? furnished,
    bool? petFriendly,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final data = await _client.rpc('get_smart_listings', params: {
          'p_user_id': userId,
          'p_category': category ?? 'property',
          'p_limit': limit,
          'p_offset': offset,
        });
        if (data is List && data.isNotEmpty) {
          final listings = data
              .map((row) => Listing.fromJson(row as Map<String, dynamic>))
              .toList();
          return _applyLocalFilters(
            listings,
            minPrice: minPrice,
            maxPrice: maxPrice,
            minBeds: minBeds,
            furnished: furnished,
            petFriendly: petFriendly,
          );
        }
      }
    } catch (_) {
      // RPC might not exist — fall through to direct query
    }

    return _fetchDirect(
      category: category,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minBeds: minBeds,
      furnished: furnished,
      petFriendly: petFriendly,
      limit: limit,
      offset: offset,
    );
  }

  /// Direct table query fallback (no RPC).
  Future<List<Listing>> _fetchDirect({
    String? category,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    bool? furnished,
    bool? petFriendly,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('listings')
        .select(_swipeFields)
        .eq('is_active', true)
        .eq('status', 'active');

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (minPrice != null) {
      query = query.gte('price', minPrice);
    }
    if (maxPrice != null) {
      query = query.lte('price', maxPrice);
    }
    if (minBeds != null && minBeds > 0) {
      query = query.gte('beds', minBeds);
    }
    if (furnished != null) {
      query = query.eq('furnished', furnished);
    }
    if (petFriendly != null) {
      query = query.eq('pet_friendly', petFriendly);
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
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    bool? furnished,
    bool? petFriendly,
  }) {
    return listings.where((listing) {
      if (minPrice != null && (listing.price ?? 0) < minPrice) return false;
      if (maxPrice != null && (listing.price ?? 0) > maxPrice) return false;
      if (minBeds != null && minBeds > 0 && (listing.beds ?? 0) < minBeds) {
        return false;
      }
      if (furnished != null && listing.furnished != furnished) return false;
      if (petFriendly != null && listing.petFriendly != petFriendly) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Fetch a single listing by ID for the detail page.
  Future<Listing?> fetchById(String listingId) async {
    final data = await _client
        .from('listings')
        .select()
        .eq('id', listingId)
        .maybeSingle();

    if (data == null) return null;
    return Listing.fromJson(data);
  }

  /// Upload listing photos to the `listing-images` bucket (Capacitor path).
  Future<List<String>> uploadListingPhotos({
    required String userId,
    required List<XFile> files,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await file.readAsBytes();
      final ext = _extensionFor(file.name);
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}-$i.$ext';
      await _client.storage.from('listing-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeFor(ext),
              upsert: true,
            ),
          );
      urls.add(_client.storage.from('listing-images').getPublicUrl(path));
    }
    return urls;
  }

  /// Cap `listing-videos` bucket — optional 10s loop for the swipe card.
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
    await _client.storage.from('listing-videos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from('listing-videos').getPublicUrl(path);
  }

  /// Insert a listing, stripping columns the live schema rejects — same
  /// retry strategy as Capacitor `saveListingWithSchemaRetry`.
  Future<Listing> createListing(Map<String, dynamic> payload) async {
    var safe = Map<String, dynamic>.from(payload);
    final removed = <String>{};

    for (var attempt = 0; attempt < 25; attempt++) {
      try {
        final data = await _client
            .from('listings')
            .insert(safe)
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

  String _extensionFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'jpg';
    return 'jpg';
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
