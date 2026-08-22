import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';

String _jwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'}))).replaceAll('=', '');
  final body = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '$header.$body.signature';
}

void main() {
  group('SupabaseService publishable key selection', () {
    test('prefers a valid SUPABASE_PUBLISHABLE_KEY', () {
      const modern = 'sb_publishable_123456789012345678901234567890';
      expect(
        SupabaseService.resolvePublishableKey(
          publishableKeyOverride: modern,
          legacyAnonKeyOverride: 'legacy.jwt.value',
        ),
        modern,
      );
    });

    test('keeps only a valid same-project legacy anon JWT', () {
      final legacy = _jwt({
        'iss': 'supabase',
        'ref': 'vplgtcguxujxwrgguxqq',
        'role': 'anon',
        'exp': 4102444800,
      });
      expect(
        SupabaseService.resolvePublishableKey(legacyAnonKeyOverride: legacy),
        legacy,
      );
    });

    test('rejects a JWT-shaped override with the wrong project or role', () {
      final bad = _jwt({
        'iss': 'supabase',
        'ref': 'wrong-project',
        'role': 'authenticated',
        'exp': 4102444800,
      });
      final resolved = SupabaseService.resolvePublishableKey(
        legacyAnonKeyOverride: bad,
      );
      expect(resolved, startsWith('sb_publishable_'));
      expect(resolved, isNot(bad));
    });

    test('release fallback is a modern publishable key, not an edited JWT', () {
      final fallback = SupabaseService.resolvePublishableKey();
      expect(fallback, startsWith('sb_publishable_'));
      expect(fallback.contains('.'), isFalse);
    });
  });
}
