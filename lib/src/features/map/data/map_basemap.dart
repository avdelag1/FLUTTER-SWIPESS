import 'package:flutter_swipes/src/core/config/app_config.dart';

/// Raster basemap. Mapbox only when a live `MAPBOX_ACCESS_TOKEN` is defined.
/// The old Cap public `pk.` is revoked (HTTP 401) — never use it as primary.
abstract final class MapBasemap {
  static bool get _mapbox => AppConfig.mapboxAccessToken.trim().isNotEmpty;

  /// Satellite-first (Cap drone pass). Esri is CORS-safe on web.
  static String get urlTemplate {
    if (_mapbox) {
      return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}?access_token={accessToken}';
    }
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  }

  /// Dark streets if aerial tiles 404.
  static const fallbackUrl =
      'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  /// Place names over satellite (Cap satellite-streets).
  static String? get labelsUrl => _mapbox
      ? null
      : 'https://a.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}@2x.png';

  static Map<String, String> get additionalOptions => _mapbox
      ? {'accessToken': AppConfig.mapboxAccessToken.trim()}
      : const {};

  static const userAgentPackageName = 'com.swipess.flutter';
}
