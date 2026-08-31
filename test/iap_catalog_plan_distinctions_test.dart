import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';

void main() {
  group('IapCatalog subscription distinctions', () {
    test('paid plans keep finite Direct Request and AI benefits explicit', () {
      final monthly = IapCatalog.subscriptions[0];
      final sixMonths = IapCatalog.subscriptions[1];
      final unlimited = IapCatalog.subscriptions[2];

      expect(monthly.name, 'Monthly');
      expect(monthly.tokens, 20);
      expect(monthly.benefits, contains('20 Direct Requests included'));
      expect(monthly.benefits, contains('AI + AI Listing Creator'));
      expect(
        monthly.benefits.any((benefit) => benefit.contains('Unlimited')),
        isFalse,
      );

      expect(sixMonths.name, '6 Months');
      expect(sixMonths.tokens, 50);
      expect(sixMonths.benefits, contains('50 Direct Requests included'));
      expect(sixMonths.benefits, contains('AI + AI Listing Creator'));
      expect(sixMonths.benefits, contains('Local Expert Knowledge'));

      expect(unlimited.name, 'Unlimited');
      expect(unlimited.durationLabel, '/1 year');
      expect(unlimited.tokens, 150);
      expect(unlimited.benefits, contains('150 Direct Requests included'));
      expect(unlimited.benefits, contains('AI + AI Listing Creator'));
      expect(unlimited.benefits, contains('Priority AI responses'));
    });
  });

  group('IapCatalog Direct Request bundles', () {
    test('Direct Request quantities and prices remain canonical', () {
      final tokens = IapCatalog.tokens;

      expect(tokens, hasLength(4));
      expect(tokens[0].tokens, 20);
      expect(tokens[0].priceLabel, r'$9.99');
      expect(tokens[1].tokens, 50);
      expect(tokens[1].priceLabel, r'$19.99');
      expect(tokens[2].tokens, 100);
      expect(tokens[2].priceLabel, r'$39.99');
      expect(tokens[3].tokens, 150);
      expect(tokens[3].priceLabel, r'$49.99');
    });
  });
}
