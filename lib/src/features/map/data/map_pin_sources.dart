import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

/// Live pins only. Fake Tulum homes / stock faces must never ride along
/// when the user picks another city — they look glued on top of the map.
List<Listing> listingsForMap(
  List<Listing> live,
) {
  return [
    for (final listing in live)
      if (listing.latitude != null && listing.longitude != null) listing,
  ];
}

List<Profile> peopleForMap(
  List<Profile> live,
) {
  return [
    for (final profile in live)
      if (profile.latitude != null && profile.longitude != null) profile,
  ];
}
