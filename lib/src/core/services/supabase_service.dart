import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Supabase client credentials are intentionally public. Prefer the modern
  // publishable key and allow build-time overrides for staging/rotation.
  // Keep a valid publishable fallback so App Store/Codemagic archives still
  // boot when no --dart-define values are supplied.
  static const String _defaultUrl =
      'https://vplgtcguxujxwrgguxqq.supabase.co';
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

  // Backward compatibility for older local/CI commands that still provide the
  // legacy environment variable. Do not hand-edit legacy JWT contents: their
  // signatures cover the exact encoded payload bytes.
  static const String _legacyAnonKeyOverride = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String get publishableKey => resolvePublishableKey(
    publishableKeyOverride: _publishableKeyOverride,
    legacyAnonKeyOverride: _legacyAnonKeyOverride,
  );

  static String resolvePublishableKey({
    String publishableKeyOverride = '',
    String legacyAnonKeyOverride = '',
  }) {
    final modern = publishableKeyOverride.trim();
    if (modern.isNotEmpty) return modern;

    final legacy = legacyAnonKeyOverride.trim();
    if (legacy.isNotEmpty) return legacy;

    return _defaultPublishableKey;
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
    if (key.isEmpty) {
      throw StateError('Missing Supabase publishable key.');
    }

    final looksModern = key.startsWith('sb_publishable_');
    final looksLegacyJwt = key.split('.').length == 3;
    if (!looksModern && !looksLegacyJwt) {
      throw StateError('Invalid Supabase client key format.');
    }
  }

  static Future<void> initialize() async {
    _validateClientConfiguration();
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: publishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
