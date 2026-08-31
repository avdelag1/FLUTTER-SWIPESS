import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';

void main() {
  group('ConciergeParse private structured payloads', () {
    test('decodes Local Brain draft without exposing transport payload', () {
      final rows = [
        {
          'id': 'vip-1',
          'name': 'Ezriyah Ben Derrick',
          'category': 'Coach, advisor & mentor',
          'description': 'Thoughtful local recommendation.',
          'recommendation_note': 'PRIVATE ROUTING RULE THAT MUST NEVER RENDER',
        },
      ];
      final payload = base64Encode(utf8.encode(jsonEncode(rows)));
      final raw = '[DRAFT:local_brain:{"payload":"$payload"}]';

      final parsed = ConciergeParse.of(raw);

      expect(parsed.localBrain, hasLength(1));
      expect(parsed.localBrain.single['name'], 'Ezriyah Ben Derrick');
      expect(parsed.cleanContent, 'Best match: Ezriyah Ben Derrick.');
      expect(parsed.cleanContent, isNot(contains('[DRAFT:')));
      expect(parsed.cleanContent, isNot(contains('payload')));
      expect(parsed.cleanContent, isNot(contains('PRIVATE ROUTING')));
    });

    test('malformed internal draft fails closed instead of rendering raw data', () {
      const raw = '[DRAFT:local_brain:{"payload":"broken-base64"';

      final parsed = ConciergeParse.of(raw);

      expect(
        parsed.cleanContent,
        'I found results, but the answer came back without a clean sentence.',
      );
      expect(parsed.cleanContent, isNot(contains('[DRAFT:')));
      expect(parsed.cleanContent, isNot(contains('broken-base64')));
    });
  });
}
