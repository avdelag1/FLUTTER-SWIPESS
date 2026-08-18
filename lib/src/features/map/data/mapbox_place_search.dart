import 'dart:convert';

import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:http/http.dart' as http;

class MapboxPlaceResult {
  const MapboxPlaceResult({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.subtitle,
    required this.featureType,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String subtitle;
  final String featureType;

  String get label => subtitle.isEmpty ? name : '$name, $subtitle';

  int get suggestedRadiusKm {
    switch (featureType) {
      case 'country':
        return 1000;
      case 'region':
        return 250;
      case 'place':
      case 'locality':
      default:
        return 25;
    }
  }
}

/// One-off worldwide place search backed by Mapbox Search Box `/forward`.
///
/// This deliberately searches only after the user submits a query instead of
/// firing a request on every keystroke. It keeps the dashboard fast and avoids
/// unnecessary search requests while still supporting cities, regions/states,
/// countries and localities around the world.
class MapboxPlaceSearch {
  const MapboxPlaceSearch._();

  static Future<List<MapboxPlaceResult>> search(String rawQuery) async {
    final query = rawQuery.trim();
    final token = AppConfig.mapboxAccessToken.trim();
    if (query.length < 2 || token.isEmpty) return const [];

    final uri = Uri.https(
      'api.mapbox.com',
      '/search/searchbox/v1/forward',
      {
        'q': query,
        'access_token': token,
        'language': 'en',
        'limit': '6',
        'types': 'place,region,locality,country',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final features = decoded['features'];
    if (features is! List) return const [];

    final results = <MapboxPlaceResult>[];
    for (final item in features) {
      if (item is! Map) continue;
      final geometry = item['geometry'];
      final properties = item['properties'];
      if (geometry is! Map || properties is! Map) continue;

      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final lng = coordinates[0];
      final lat = coordinates[1];
      if (lng is! num || lat is! num) continue;

      final name = properties['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final featureType =
          properties['feature_type']?.toString().trim().toLowerCase() ?? 'place';

      final context = properties['context'];
      String country = '';
      if (context is Map) {
        final countryContext = context['country'];
        if (countryContext is Map) {
          country = countryContext['name']?.toString().trim() ?? '';
        }
      }

      final placeFormatted = properties['place_formatted']?.toString().trim();
      final subtitle = (placeFormatted != null && placeFormatted.isNotEmpty)
          ? placeFormatted
          : country;

      results.add(
        MapboxPlaceResult(
          name: name,
          country: country,
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
          subtitle: subtitle,
          featureType: featureType,
        ),
      );
    }
    return results;
  }
}
