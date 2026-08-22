import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/legal/domain/contract_templates.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';

void main() {
  test('Legal ships multiple editable lease examples', () {
    final leases = contractTemplates
        .where((template) => template.category.toLowerCase() == 'lease')
        .toList();
    expect(leases.length, greaterThanOrEqualTo(5));
    expect(leases.any((t) => t.id.contains('month')), isTrue);
    expect(leases.any((t) => t.id.contains('furnished')), isTrue);
  });

  test('Premium packages include 20, 50 and 150 Direct Requests', () {
    expect(
      IapCatalog.subscriptions.map((offer) => offer.tokens).toList(),
      equals(<int?>[20, 50, 150]),
    );
  });

  test('Yearly Unlimited exposes the full premium capability set', () {
    expect(SubscriptionTier.premium.canUseAI, isTrue);
    expect(SubscriptionTier.premium.canUseLegal, isTrue);
    expect(SubscriptionTier.premium.canViewEvents, isTrue);
    expect(SubscriptionTier.premium.canUseVirtualCard, isTrue);
    expect(SubscriptionTier.premium.maxListings, greaterThan(100000));
  });

  test('Virtual Local ID stays available on the free tier', () {
    expect(SubscriptionTier.free.canUseVirtualCard, isTrue);
    expect(SubscriptionTier.free.canUseAI, isFalse);
    expect(SubscriptionTier.free.canUseLegal, isFalse);
    expect(SubscriptionTier.free.canViewEvents, isFalse);
  });
}
