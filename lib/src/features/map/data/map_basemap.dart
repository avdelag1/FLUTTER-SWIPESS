import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';

/// Web basemap configuration.
///
/// When a Mapbox public token is present we deliberately use Mapbox's standard
/// raster styles rather than a custom style id. The custom style path was able
/// to fail as a completely black map in browsers even while the surrounding
/// Flutter controls rendered correctly. If no Mapbox token is available we
/// fall back to Carto so discovery is never left blank.
abstract final class MapBasemap {
  static bool get _mapbox => AppConfig.mapboxAccessToken.trim().isNotEmpty;

  static const fallbackDarkUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';
  static const fallbackLightUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

  static const subdomains = ['a', 'b', 'c', 'd'];

  static String urlTemplate(bool isLight) {
    if (_mapbox) {
      final style = isLight ? 'light-v11' : 'dark-v11';
      return 'https://api.mapbox.com/styles/v1/mapbox/$style/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}';
    }
    return isLight ? fallbackLightUrl : fallbackDarkUrl;
  }

  static String? get labelsUrl => null;

  static Map<String, String> get additionalOptions =>
      _mapbox ? {'accessToken': AppConfig.mapboxAccessToken.trim()} : const {};

  static const userAgentPackageName = 'com.swipess.flutter';

  static const canvas = Color(0xFF0A0A0D);
  static const listing = Color(0xFFFF4D00);
  static const listingDeep = Color(0xFFE4007C);
  static const people = Color(0xFFEC4899);
  static const peopleDeep = Color(0xFFBE185D);
  static const radiusFill = Color(0x203B82F6);
  static const radiusStroke = Color(0xFF3B82F6);
}
