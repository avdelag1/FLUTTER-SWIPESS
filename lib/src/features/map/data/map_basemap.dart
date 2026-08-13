import 'package:flutter_swipes/src/core/config/app_config.dart';

/// Raster basemap. Satellite-first so the open view reads as a drone pass,
/// with a streets fallback when imagery tiles 404 (common on web).
abstract final class MapBasemap {
  static bool get _mapbox => AppConfig.hasMapboxToken;

  /// Mapbox satellite-streets (256px) or Esri World Imagery.
  static String get urlTemplate {
    if (_mapbox) {
      return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}?access_token={accessToken}';
    }
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  }

  /// Carto Voyager — labeled streets if the aerial tile 404s.
  static const fallbackUrl =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  static Map<String, String> get additionalOptions => _mapbox
      ? {'accessToken': AppConfig.mapboxAccessToken}
      : const {};

  static const userAgentPackageName = 'com.swipess.flutter';
}
