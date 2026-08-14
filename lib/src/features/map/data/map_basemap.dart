import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';

/// One dark basemap. No satellite-on-streets stack — that muddy mix is gone.
abstract final class MapBasemap {
  static bool get _mapbox => AppConfig.mapboxAccessToken.trim().isNotEmpty;

  /// Carto Dark Matter — black canvas, readable streets, matches Swipess.
  static const streetsUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';

  static const subdomains = ['a', 'b', 'c', 'd'];

  static String get urlTemplate {
    if (_mapbox) {
      return 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}?access_token={accessToken}';
    }
    return streetsUrl;
  }

  static String? get labelsUrl => null;

  static Map<String, String> get additionalOptions => _mapbox
      ? {'accessToken': AppConfig.mapboxAccessToken.trim()}
      : const {};

  static const userAgentPackageName = 'com.swipess.flutter';

  static const canvas = Color(0xFF0A0A0D);
  static const listing = Color(0xFFFF4D00);
  static const listingDeep = Color(0xFFE4007C);
  static const people = Color(0xFFEC4899);
  static const peopleDeep = Color(0xFFBE185D);
  static const radiusFill = Color(0x22FF4D00);
  static const radiusStroke = Color(0xCCFF4D00);
}
