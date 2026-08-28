import 'dart:convert';

import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ensures native store builds can configure Mapbox even when Xcode archives
/// the app without Flutter `--dart-define` arguments.
///
/// The token is a Mapbox public (`pk.`) client token. The web build already
/// embeds the same public token. Vercel also publishes it at a tiny Swipess
/// runtime-config endpoint so native builds can recover it without hardcoding a
/// token in GitHub.
abstract final class MapboxRuntimeConfig {
  static const _configUrl = 'https://www.swipess.com/mapbox-config.json';
  static const _cacheKey = 'swipess_mapbox_public_token_v1';

  static String? _runtimeToken;
  static Future<bool>? _inFlight;

  static bool get isConfigured =>
      AppConfig.hasMapboxToken || (_runtimeToken?.trim().isNotEmpty ?? false);

  static bool _valid(String? token) {
    final value = token?.trim();
    return value != null && value.isNotEmpty && value.startsWith('pk.');
  }

  static Future<bool> ensureConfigured() {
    final compileTimeToken = AppConfig.mapboxAccessToken.trim();
    if (_valid(compileTimeToken)) {
      MapboxOptions.setAccessToken(compileTimeToken);
      return Future<bool>.value(true);
    }

    final memoryToken = _runtimeToken?.trim();
    if (_valid(memoryToken)) {
      MapboxOptions.setAccessToken(memoryToken!);
      return Future<bool>.value(true);
    }

    return _inFlight ??= _restoreOrFetch();
  }

  static Future<bool> _restoreOrFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey)?.trim();
      if (_valid(cached)) {
        _runtimeToken = cached;
        MapboxOptions.setAccessToken(cached!);
        return true;
      }
    } catch (_) {
      // A preferences failure must never block the network fallback.
    }

    return _fetchAndConfigure();
  }

  static Future<bool> _fetchAndConfigure() async {
    try {
      final response = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final token = (decoded['mapboxAccessToken'] as String?)?.trim();
      if (!_valid(token)) return false;

      _runtimeToken = token;
      MapboxOptions.setAccessToken(token!);

      // Store builds often lack dart-defines. Persisting the public token means
      // every launch after the first successful fetch can create Mapbox
      // immediately instead of paying another network round-trip when Map opens.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, token);
      } catch (_) {}

      return true;
    } catch (_) {
      return false;
    } finally {
      _inFlight = null;
    }
  }
}
