import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final marketSwipeRepositoryProvider = Provider<MarketSwipeRepository>((ref) {
  return MarketSwipeRepository(ref.watch(supabaseClientProvider));
});

class MarketSwipeRepository {
  MarketSwipeRepository(this._client);

  final SupabaseClient _client;

  Future<List<Listing>> fetch({
    required String category,
    required String marketCity,
    required String marketCountry,
    String? interestType,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    int? minBaths,
    bool? furnished,
    bool? petFriendly,
    List<String> propertyTypes = const [],
    int limit = 40,
    int offset = 0,
  }) async {
    if (_client.auth.currentUser == null) return const [];

    // Authenticated discovery intentionally fails closed. Falling back to a
    // direct table query here would bypass the Super Admin market matrix.
    final data = await _client.rpc(
      'app_get_smart_listings',
      params: {
        'p_category': category,
        'p_city': marketCity,
        'p_country': marketCountry,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (data is! List) return const [];

    final listings = data
        .whereType<Map>()
        .map((row) => Listing.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    return listings.where((listing) {
      if (interestType != null &&
          interestType.isNotEmpty &&
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
        final type = listing.propertyType;
        if (type == null || !propertyTypes.contains(type)) return false;
      }
      return true;
    }).toList(growable: false);
  }
}
