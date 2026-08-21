import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';

void main() {
  group('IapCatalog subscription distinctions', () {
    test('plans keep distinct Direct Request and AI value', () {
      final monthly = IapCatalog.subscriptions[0];
      final semiAnnual = IapCatalog.subscriptions[1];
      final yearly = IapCatalog.subscriptions[2];

      expect(monthly.name, 'Here Now');
      expect(
        monthly.benefits,
        contains('15 Direct Requests included — only spent when accepted'),
      );
      expect(monthly.benefits, contains('AI Concierge — 15 messages/day'));
      expect(monthly.benefits, contains('AI Listing Creator — 3/month'));

      expect(semiAnnual.name, 'Live Local');
      expect(semiAnnual.popular, isTrue);
      expect(
        semiAnnual.benefits,
        contains('25 Direct Requests included — only spent when accepted'),
      );
      expect(semiAnnual.benefits, contains('AI Concierge — 50 messages/day'));
      expect(semiAnnual.benefits, contains('AI Listing Creator — 10/month'));
      expect(semiAnnual.benefits, contains('Priority matching & visibility'));

      expect(yearly.name, 'Pro');
      expect(
        yearly.benefits,
        contains('50 Direct Requests included — only spent when accepted'),
      );
      expect(yearly.benefits, contains('AI Concierge — Unlimited'));
      expect(yearly.benefits, contains('AI Listing Creator — Unlimited'));
    });
  });

  group('IapCatalog token bundles', () {
    test('Direct Request quantities and prices remain store-compatible', () {
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
      expect(
        tokens.every(
          (offer) =>
              offer.description?.contains('charged only when accepted') == true,
        ),
        isTrue,
      );
    });
  });
}
