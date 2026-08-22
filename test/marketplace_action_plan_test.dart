import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/needs/domain/marketplace_action_plan.dart';

void main() {
  test('normalizes safe marketplace categories', () {
    final plan = MarketplaceActionPlan.fromJson({
      'action': 'create_need',
      'summary': 'Need a scooter tomorrow',
      'category': 'motos',
      'need': {
        'title': 'Scooter tomorrow',
        'city': 'Tulum',
        'budget_max': 500,
        'urgency': 'today',
      },
    });

    expect(plan.type, MarketplaceActionType.createNeed);
    expect(plan.category, 'motorcycle');
    expect(plan.need?.category, 'motorcycle');
    expect(plan.need?.budgetMax, 500);
    expect(plan.need?.urgency, 'today');
    expect(plan.requiresConfirmation, isTrue);
  });

  test('rejects unsupported categories instead of inventing actions', () {
    final plan = MarketplaceActionPlan.fromJson({
      'action': 'create_need',
      'summary': 'Something unsupported',
      'category': 'event',
    });

    expect(plan.category, isNull);
    expect(plan.need, isNull);
  });

  test('search actions are read-only and need no mutation confirmation', () {
    final plan = MarketplaceActionPlan.fromJson({
      'action': 'search_marketplace',
      'summary': 'Find a villa',
      'category': 'property',
      'query': 'villa in Tulum',
    });

    expect(plan.type, MarketplaceActionType.searchMarketplace);
    expect(plan.requiresConfirmation, isFalse);
  });
}
