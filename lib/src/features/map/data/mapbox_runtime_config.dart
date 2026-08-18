import 'dart:convert';

import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Ensures native store builds can configure Mapbox even when Xcode archives
/// the app without Flutter `--dart-define` arguments.
///
/// The token is a Mapbox public (`pk.`) client token. The web build already
/// embeds the same public token. Vercel also publishes it at a tiny Swipess
/// runtime-config endpoint so native builds can recover it without hardcoding a
/// token in GitHub.
abstract final class MapboxRuntimeConfig {
  static const _configUrl = 'https://www.swipess.com/mapbox-config.json';

  static String? _runtimeToken;
  static Future<bool>? _inFlight;

  static bool get isConfigured =>
      AppConfig.hasMapboxToken || (_runtimeToken?.trim().isNotEmpty ?? false);

  static Future<bool> ensureConfigured() {
    final compileTimeToken = AppConfig.mapboxAccessToken.trim();
    if (compileTimeToken.isNotEmpty) {
      MapboxOptions.setAccessToken(compileTimeToken);
      return Future<bool>.value(true);
    }

    final cached = _runtimeToken?.trim();
    if (cached != null && cached.isNotEmpty) {
      MapboxOptions.setAccessToken(cached);
      return Future<bool>.value(true);
    }

    return _inFlight ??= _fetchAndConfigure();
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
      if (token == null || token.isEmpty || !token.startsWith('pk.')) {
        return false;
      }

      _runtimeToken = token;
      MapboxOptions.setAccessToken(token);
      return true;
    } catch (_) {
      return false;
    } finally {
      _inFlight = null;
    }
  }
}
