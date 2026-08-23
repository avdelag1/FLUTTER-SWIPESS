import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Supabase client credentials are intentionally public. Prefer the modern
  // publishable key and allow build-time overrides for staging/rotation.
  // Keep a valid publishable fallback so a malformed CI/Vercel override cannot
  // make production fail before Flutter renders its first frame.
  static const String _projectRef = 'vplgtcguxujxwrgguxqq';
  static const String _defaultUrl = 'https://$_projectRef.supabase.co';
  static const String _defaultPublishableKey =
      'sb_publishable_FA0BseFSS6zM7Y8K3w8zLQ_d8BXqEuV';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );

  static const String _publishableKeyOverride = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  // Legacy compatibility is deliberately strict. Production previously broke
  // because a JWT-shaped string was accepted only because it contained two
  // dots. We now require the anon role and this project's ref before honoring
  // SUPABASE_ANON_KEY at all.
  static const String _legacyAnonKeyOverride = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String get publishableKey => resolvePublishableKey(
    publishableKeyOverride: _publishableKeyOverride,
    legacyAnonKeyOverride: _legacyAnonKeyOverride,
  );

  // Transitional alias for repositories/config helpers that still use the old
  // Supabase terminology. Keep this until those call sites are migrated.
  @Deprecated('Use publishableKey instead.')
  static String get anonKey => publishableKey;

  static String resolvePublishableKey({
    String publishableKeyOverride = '',
    String legacyAnonKeyOverride = '',
  }) {
    final modern = publishableKeyOverride.trim();
    if (_isValidModernPublishableKey(modern)) return modern;

    final legacy = legacyAnonKeyOverride.trim();
    if (_isValidLegacyAnonJwt(legacy)) return legacy;

    // Invalid/empty build-time overrides fail closed to the known-good public
    // publishable key instead of taking the whole app offline.
    return _defaultPublishableKey;
  }

  static bool _isValidModernPublishableKey(String key) {
    if (!key.startsWith('sb_publishable_')) return false;
    return key.length >= 32 && !key.contains(RegExp(r'\s'));
  }

  static bool _isValidLegacyAnonJwt(String key) {
    final parts = key.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return false;

      final role = payload['role']?.toString();
      final ref = payload['ref']?.toString();
      final issuer = payload['iss']?.toString();
      if (role != 'anon' || ref != _projectRef || issuer != 'supabase') {
        return false;
      }

      final expRaw = payload['exp'];
      if (expRaw is num) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          expRaw.toInt() * 1000,
          isUtc: true,
        );
        if (!expiresAt.isAfter(DateTime.now().toUtc())) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _validateClientConfiguration() {
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !uri.host.endsWith('.supabase.co')) {
      throw StateError('Invalid SUPABASE_URL configuration.');
    }

    final key = publishableKey.trim();
    if (!_isValidModernPublishableKey(key) && !_isValidLegacyAnonJwt(key)) {
      throw StateError('Invalid Supabase client key configuration.');
    }
  }

  static Future<void> initialize() async {
    _validateClientConfiguration();
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: publishableKey,
      storageOptions: const StorageClientOptions(retryAttempts: 5),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
