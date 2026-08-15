import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';

/// The official custom Mapbox styles for Swipess.
abstract final class MapBasemap {
  static bool get _mapbox => AppConfig.mapboxAccessToken.trim().isNotEmpty;

  // Custom Swipess Mapbox styles provided by user.
  static const darkStyle = 'cmshydgsr00xz01s65m0x6u4n';
  static const lightStyle = 'cmshyf3kh00gw01s9gu3yelwz';

  // Standard fallback map tiles
  static const fallbackDarkUrl = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';
  static const fallbackLightUrl = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

  static const subdomains = ['a', 'b', 'c', 'd'];

  static String urlTemplate(bool isLight) {
    if (_mapbox) {
      final styleId = isLight ? lightStyle : darkStyle;
      return 'https://api.mapbox.com/styles/v1/avdelag123/$styleId/tiles/256/{z}/{x}/{y}?access_token={accessToken}';
    }
    return isLight ? fallbackLightUrl : fallbackDarkUrl;
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
  static const radiusFill = Color(0x10FFFFFF);
  static const radiusStroke = Color(0x33FFFFFF);
}
