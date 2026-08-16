import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';

void main() {
  group('IapCatalog subscription distinctions', () {
    test('paid plans keep their AI benefits separate', () {
      final monthly = IapCatalog.subscriptions[0];
      final semiAnnual = IapCatalog.subscriptions[1];
      final yearly = IapCatalog.subscriptions[2];

      expect(monthly.name, 'Monthly');
      expect(monthly.benefits, contains('AI Concierge — 15 messages/day'));
      expect(monthly.benefits, contains('AI Listing Creator — 3/month'));
      expect(
        monthly.benefits.any((benefit) => benefit.contains('Unlimited')),
        isFalse,
      );

      expect(semiAnnual.name, 'Semi-Annual');
      expect(
        semiAnnual.benefits,
        contains('AI Concierge — 50 messages/day'),
      );
      expect(semiAnnual.benefits, contains('AI Listing Creator — 10/month'));
      expect(semiAnnual.benefits, contains('Local Expert Knowledge'));

      expect(yearly.name, 'Yearly');
      expect(yearly.benefits, contains('AI Concierge — Unlimited'));
      expect(yearly.benefits, contains('AI Listing Creator — Unlimited'));
      expect(yearly.benefits, contains('Priority AI Responses'));
    });
  });

  group('IapCatalog token bundles', () {
    test('message token quantities and prices remain canonical', () {
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
