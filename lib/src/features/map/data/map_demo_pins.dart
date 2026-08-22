import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:latlong2/latlong.dart';

/// Live pins only. Fake Tulum homes / stock faces must never ride along
/// when the user picks another city — they look glued on top of the map.
List<Listing> listingsForMap(List<Listing> live, LatLng center, String city) {
  return [
    for (final listing in live)
      if (listing.latitude != null && listing.longitude != null) listing,
  ];
}

List<Profile> peopleForMap(List<Profile> live, LatLng center, String city) {
  return [
    for (final profile in live)
      if (profile.latitude != null && profile.longitude != null) profile,
  ];
}

/// Spread demo homes inside a 10 km ring so every pin stays in-radius.
List<Listing> demoMapListings(LatLng center, String city) {
  final rows = <(double, double, String, String, double, String)>[
    (
      0.032,
      -0.028,
      'Luxury Oasis in $city',
      'Downtown',
      2400,
      'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=400&q=70',
    ),
    (
      -0.036,
      0.030,
      'Modern Villa',
      'Northside',
      3100,
      'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=400&q=70',
    ),
    (
      0.022,
      0.040,
      'City Center Studio',
      'Central',
      1800,
      'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=400&q=70',
    ),
    (
      -0.041,
      -0.024,
      'Casa Blanca',
      'West End',
      2650,
      'https://images.unsplash.com/photo-1600585154340-be36641d3ee6?auto=format&fit=crop&w=400&q=70',
    ),
    (
      0.038,
      0.012,
      'High-Rise Loft',
      'East Village',
      2950,
      'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=400&q=70',
    ),
    (
      -0.018,
      0.042,
      'Exclusive Estate',
      'Uptown',
      2100,
      'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdbc?auto=format&fit=crop&w=400&q=70',
    ),
  ];
  return [
    for (var i = 0; i < rows.length; i++)
      Listing(
        id: 'map-demo-$i',
        title: rows[i].$3,
        category: 'property',
        city: city,
        neighborhood: rows[i].$4,
        price: rows[i].$5,
        currency: 'USD',
        latitude: center.latitude + rows[i].$1,
        longitude: center.longitude + rows[i].$2,
        images: [rows[i].$6],
      ),
  ];
}

/// Portrait pins — never reuse listing interiors so people stay distinct.
List<Profile> demoMapProfiles(LatLng center, String city) {
  const rows = <(double, double, String, String)>[
    (
      0.012,
      -0.038,
      'Maya Chen',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=70',
    ),
    (
      -0.024,
      0.016,
      'Leo Santos',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=70',
    ),
    (
      0.008,
      0.034,
      'Sofia Reyes',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=70',
    ),
    (
      -0.030,
      -0.010,
      'Noah Park',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=70',
    ),
  ];
  return [
    for (var i = 0; i < rows.length; i++)
      Profile(
        id: 'map-demo-person-$i',
        fullName: rows[i].$3,
        city: city,
        role: 'Active now',
        latitude: center.latitude + rows[i].$1,
        longitude: center.longitude + rows[i].$2,
        avatarUrl: rows[i].$4,
      ),
  ];
}
