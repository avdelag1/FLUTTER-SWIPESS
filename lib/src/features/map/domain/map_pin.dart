import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

class MapPin {
  final bool isListing;
  final Listing? listing;
  final Profile? profile;
  final double lat;
  final double lng;

  MapPin.listing(this.listing)
    : isListing = true,
      profile = null,
      lat = listing!.latitude!,
      lng = listing.longitude!;

  MapPin.profile(this.profile)
    : isListing = false,
      listing = null,
      lat = profile!.latitude!,
      lng = profile.longitude!;

  MapPin.listingAt(this.listing, this.lat, this.lng)
    : isListing = true,
      profile = null;

  MapPin.profileAt(this.profile, this.lat, this.lng)
    : isListing = false,
      listing = null;

  MapPin.scattered(MapPin original, this.lat, this.lng)
    : isListing = original.isListing,
      listing = original.listing,
      profile = original.profile;

  String get id => isListing ? listing!.id : profile!.id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPin && other.isListing == isListing && other.id == id;

  @override
  int get hashCode => Object.hash(isListing, id);
}

/// Keeps native and web map filters aligned with categories that actually
/// exist in the discovery providers. Events have their own data source and
/// must not be advertised here until they are represented by [MapPin].
bool mapPinMatchesCategory(MapPin pin, String category) {
  if (category == 'all') return true;
  if (category == 'people') return !pin.isListing;
  if (!pin.isListing) return false;

  final listingCategory = pin.listing?.category?.toLowerCase() ?? '';
  final listingType = pin.listing?.listingType?.toLowerCase() ?? '';
  return switch (category) {
    'properties' => listingCategory == 'property',
    'services' =>
      listingCategory == 'worker' ||
          listingCategory == 'service' ||
          listingCategory == 'services' ||
          listingType == 'service',
    'vehicles' => const {
      'motorcycle',
      'bicycle',
      'yacht',
      'vehicle',
    }.contains(listingCategory),
    _ => false,
  };
}
