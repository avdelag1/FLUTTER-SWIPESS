import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_locations.dart';

class DiscoveryLocation {
  const DiscoveryLocation({
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.guests = 2,
    this.dateLabel = 'Any date',
  });

  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final int guests;
  final String dateLabel;

  String get label => '$city, $country';

  DiscoveryLocation copyWith({
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    int? guests,
    String? dateLabel,
  }) {
    return DiscoveryLocation(
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      guests: guests ?? this.guests,
      dateLabel: dateLabel ?? this.dateLabel,
    );
  }
}

class DiscoveryLocationNotifier extends Notifier<DiscoveryLocation> {
  @override
  DiscoveryLocation build() {
    final tulum = ListingLocations.resolve('Tulum')!;
    return DiscoveryLocation(
      city: 'Tulum',
      country: tulum.country,
      latitude: tulum.lat,
      longitude: tulum.lng,
    );
  }

  void setCity(String city) {
    final resolved = ListingLocations.resolve(city);
    if (resolved == null) return;
    state = state.copyWith(
      city: city,
      country: resolved.country,
      latitude: resolved.lat,
      longitude: resolved.lng,
    );
  }

  void setGuests(int guests) {
    state = state.copyWith(guests: guests.clamp(1, 16));
  }

  void setDateLabel(String label) {
    state = state.copyWith(dateLabel: label);
  }
}

final discoveryLocationProvider =
    NotifierProvider<DiscoveryLocationNotifier, DiscoveryLocation>(
  DiscoveryLocationNotifier.new,
);
