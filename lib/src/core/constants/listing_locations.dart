/// Curated city coordinates so listings can publish without GPS,
/// matching Capacitor `resolveListingCoordinatesSync`.
class ListingLocations {
  static const Map<
    String,
    ({double lat, double lng, String country, String state})
  >
  cities = {
    'Tulum': (
      lat: 20.2111,
      lng: -87.4653,
      country: 'Mexico',
      state: 'Quintana Roo',
    ),
    'Playa del Carmen': (
      lat: 20.6296,
      lng: -87.0739,
      country: 'Mexico',
      state: 'Quintana Roo',
    ),
    'Cancún': (
      lat: 21.1619,
      lng: -86.8515,
      country: 'Mexico',
      state: 'Quintana Roo',
    ),
    'Cancun': (
      lat: 21.1619,
      lng: -86.8515,
      country: 'Mexico',
      state: 'Quintana Roo',
    ),
    'Cozumel': (
      lat: 20.4318,
      lng: -86.9194,
      country: 'Mexico',
      state: 'Quintana Roo',
    ),
    'Mexico City': (
      lat: 19.4326,
      lng: -99.1332,
      country: 'Mexico',
      state: 'Mexico City',
    ),
    'Guadalajara': (
      lat: 20.6597,
      lng: -103.3496,
      country: 'Mexico',
      state: 'Jalisco',
    ),
    'Monterrey': (
      lat: 25.6866,
      lng: -100.3161,
      country: 'Mexico',
      state: 'Nuevo León',
    ),
    'Mérida': (
      lat: 20.9674,
      lng: -89.5926,
      country: 'Mexico',
      state: 'Yucatán',
    ),
    'Merida': (
      lat: 20.9674,
      lng: -89.5926,
      country: 'Mexico',
      state: 'Yucatán',
    ),
    'Querétaro': (
      lat: 20.5888,
      lng: -100.3899,
      country: 'Mexico',
      state: 'Querétaro',
    ),
    'Puerto Vallarta': (
      lat: 20.6534,
      lng: -105.2253,
      country: 'Mexico',
      state: 'Jalisco',
    ),
    'Miami': (
      lat: 25.7617,
      lng: -80.1918,
      country: 'United States',
      state: 'Florida',
    ),
    'Los Angeles': (
      lat: 34.0522,
      lng: -118.2437,
      country: 'United States',
      state: 'California',
    ),
    'New York City': (
      lat: 40.7128,
      lng: -74.0060,
      country: 'United States',
      state: 'New York',
    ),
    'Austin': (
      lat: 30.2672,
      lng: -97.7431,
      country: 'United States',
      state: 'Texas',
    ),
    'Barcelona': (
      lat: 41.3874,
      lng: 2.1686,
      country: 'Spain',
      state: 'Catalonia',
    ),
    'Madrid': (lat: 40.4168, lng: -3.7038, country: 'Spain', state: 'Madrid'),
    'Lisbon': (
      lat: 38.7223,
      lng: -9.1393,
      country: 'Portugal',
      state: 'Lisbon',
    ),
  };

  static ({double lat, double lng, String country, String state})? resolve(
    String? city,
  ) {
    if (city == null || city.trim().isEmpty) return null;
    final key = city.trim();
    final exact = cities[key];
    if (exact != null) return exact;
    for (final entry in cities.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
    }
    return null;
  }
}
