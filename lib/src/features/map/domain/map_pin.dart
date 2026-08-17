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
}
