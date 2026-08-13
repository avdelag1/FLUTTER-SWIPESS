/// Cap `PASSPORT_QUICK_CITIES`.
class PassportCity {
  const PassportCity({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String country;
  final double lat;
  final double lng;

  String get label => '$name, $country';
}

abstract final class PassportCities {
  static const hub = PassportCity(
    name: 'Tulum',
    country: 'Mexico',
    lat: 20.2114,
    lng: -87.4654,
  );

  static const all = <PassportCity>[
    PassportCity(name: 'Miami', country: 'United States', lat: 25.7617, lng: -80.1918),
    PassportCity(name: 'Medellín', country: 'Colombia', lat: 6.2442, lng: -75.5812),
    PassportCity(name: 'Tulum', country: 'Mexico', lat: 20.2114, lng: -87.4654),
    PassportCity(name: 'Cancún', country: 'Mexico', lat: 21.1619, lng: -86.8515),
    PassportCity(name: 'Cabo', country: 'Mexico', lat: 22.8905, lng: -109.9167),
    PassportCity(name: 'Cartagena', country: 'Colombia', lat: 10.3910, lng: -75.4794),
    PassportCity(name: 'Dubai', country: 'UAE', lat: 25.2048, lng: 55.2708),
    PassportCity(name: 'Marrakech', country: 'Morocco', lat: 31.6295, lng: -7.9811),
    PassportCity(name: 'Paris', country: 'France', lat: 48.8566, lng: 2.3522),
    PassportCity(name: 'London', country: 'United Kingdom', lat: 51.5074, lng: -0.1278),
    PassportCity(name: 'Rome', country: 'Italy', lat: 41.9028, lng: 12.4964),
    PassportCity(name: 'Barcelona', country: 'Spain', lat: 41.3851, lng: 2.1734),
    PassportCity(name: 'Ibiza', country: 'Spain', lat: 38.9067, lng: 1.4206),
    PassportCity(name: 'Mykonos', country: 'Greece', lat: 37.4467, lng: 25.3289),
    PassportCity(name: 'Santorini', country: 'Greece', lat: 36.3932, lng: 25.4615),
    PassportCity(name: 'Monaco', country: 'Monaco', lat: 43.7384, lng: 7.4246),
    PassportCity(name: 'New York', country: 'United States', lat: 40.7128, lng: -74.0060),
    PassportCity(name: 'LA', country: 'United States', lat: 34.0522, lng: -118.2437),
    PassportCity(name: 'Las Vegas', country: 'United States', lat: 36.1699, lng: -115.1398),
    PassportCity(name: 'Tokyo', country: 'Japan', lat: 35.6762, lng: 139.6503),
    PassportCity(name: 'Seoul', country: 'South Korea', lat: 37.5665, lng: 126.9780),
    PassportCity(name: 'Bali', country: 'Indonesia', lat: -8.4095, lng: 115.1889),
    PassportCity(name: 'Singapore', country: 'Singapore', lat: 1.3521, lng: 103.8198),
    PassportCity(name: 'Bangkok', country: 'Thailand', lat: 13.7563, lng: 100.5018),
    PassportCity(name: 'Sydney', country: 'Australia', lat: -33.8688, lng: 151.2093),
    PassportCity(name: 'Rio', country: 'Brazil', lat: -22.9068, lng: -43.1729),
    PassportCity(name: 'Punta Cana', country: 'Dominican Republic', lat: 18.5601, lng: -68.3725),
  ];
}
