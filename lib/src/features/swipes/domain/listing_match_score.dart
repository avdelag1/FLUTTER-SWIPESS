import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';

/// Cap `useSmartListingMatching` — score a listing against live filters.
///
/// Returns 0 when the user has not set extra filter signals, matching Cap
/// `SwipeMatchMeter` which hides itself unless genuine filter data exists.
int listingMatchPercentage(Listing listing, SwipeFilter filters) {
  if (!_hasFilterSignals(filters)) return 0;

  var hits = 0;
  var total = 0;

  void check(bool? ok) {
    total++;
    if (ok == true) hits++;
  }

  if (filters.interestType != 'both') {
    final type = listing.listingType;
    check(
      type == null ||
          type == filters.interestType ||
          (filters.interestType == 'sale' && type == 'buy'),
    );
  }

  if (filters.minPrice != null || filters.maxPrice != null) {
    final price = listing.price;
    check(
      price != null &&
          (filters.minPrice == null || price >= filters.minPrice!) &&
          (filters.maxPrice == null || price <= filters.maxPrice!),
    );
  }

  if (filters.minBeds != null) {
    final beds = listing.beds ?? listing.bedrooms;
    check(beds != null && beds >= filters.minBeds!);
  }

  if (filters.minBaths != null) {
    final baths = listing.baths ?? listing.bathrooms;
    check(baths != null && baths >= filters.minBaths!);
  }

  if (filters.furnished != null) {
    check(listing.furnished == filters.furnished);
  }

  if (filters.petFriendly != null) {
    check(listing.petFriendly == filters.petFriendly);
  }

  if (filters.propertyTypes.isNotEmpty) {
    final type = listing.propertyType;
    check(type != null && filters.propertyTypes.contains(type));
  }

  final city = filters.city?.trim();
  if (city != null && city.isNotEmpty) {
    final hay = '${listing.city ?? ''} ${listing.location ?? ''} ${listing.neighborhood ?? ''}'
        .toLowerCase();
    check(hay.contains(city.toLowerCase()));
  }

  if (total == 0) return 0;
  final raw = (hits / total * 100).round();
  if (raw <= 0) return 55;
  return raw.clamp(55, 99);
}

bool _hasFilterSignals(SwipeFilter filters) {
  return filters.minPrice != null ||
      filters.maxPrice != null ||
      filters.minBeds != null ||
      filters.minBaths != null ||
      filters.furnished != null ||
      filters.petFriendly != null ||
      filters.propertyTypes.isNotEmpty ||
      (filters.city != null && filters.city!.trim().isNotEmpty) ||
      filters.interestType != 'both';
}
