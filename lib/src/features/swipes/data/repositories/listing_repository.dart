import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

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
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        // Try the smart RPC first
        final data = await _client.rpc('get_smart_listings', params: {
          'p_user_id': userId,
          'p_category': category ?? 'property',
          'p_limit': limit,
          'p_offset': offset,
        });
        if (data is List && data.isNotEmpty) {
          return data
              .map((row) => Listing.fromJson(row as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // RPC might not exist — fall through to direct query
    }

    // Fallback: direct query
    return _fetchDirect(category: category, limit: limit, offset: offset);
  }

  /// Direct table query fallback (no RPC).
  Future<List<Listing>> _fetchDirect({
    String? category,
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

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
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
}
