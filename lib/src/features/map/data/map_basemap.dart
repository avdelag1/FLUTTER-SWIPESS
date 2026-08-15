import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';

/// A photographic, high-information map with a clean label overlay.
abstract final class MapBasemap {
  static bool get _mapbox => AppConfig.mapboxAccessToken.trim().isNotEmpty;

  static const satelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const streetsUrl = satelliteUrl;
  static const labelOverlayUrl =
      'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}@2x.png';

  static const subdomains = ['a', 'b', 'c', 'd'];

  static String get urlTemplate {
    if (_mapbox) {
      return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}?access_token={accessToken}';
    }
    return streetsUrl;
  }

  static String? get labelsUrl => _mapbox ? null : labelOverlayUrl;

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
