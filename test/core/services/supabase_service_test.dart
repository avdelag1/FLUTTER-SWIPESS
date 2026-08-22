import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';

void main() {
  group('SupabaseService publishable key selection', () {
    test('prefers SUPABASE_PUBLISHABLE_KEY over the legacy override', () {
      expect(
        SupabaseService.resolvePublishableKey(
          publishableKeyOverride: 'sb_publishable_test',
          legacyAnonKeyOverride: 'legacy.jwt.value',
        ),
        'sb_publishable_test',
      );
    });

    test('keeps SUPABASE_ANON_KEY backward compatibility', () {
      expect(
        SupabaseService.resolvePublishableKey(
          legacyAnonKeyOverride: 'legacy.jwt.value',
        ),
        'legacy.jwt.value',
      );
    });

    test('release fallback is a modern publishable key, not an edited JWT', () {
      final fallback = SupabaseService.resolvePublishableKey();
      expect(fallback, startsWith('sb_publishable_'));
      expect(fallback.contains('.'), isFalse);
    });
  });
}
