import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/business/domain/business_visit.dart';
import 'package:flutter_swipes/src/features/legal/domain/lawyer_workspace.dart';
import 'package:flutter_swipes/src/features/session/domain/app_market_context.dart';

void main() {
  test('market context fails open only for missing feature keys', () {
    final market = AppMarketContext.fromJson({
      'configured': true,
      'effective_open': true,
      'city': 'Tulum',
      'features': {
        'properties': true,
        'workers': false,
      },
    });

    expect(market.configured, isTrue);
    expect(market.city, 'Tulum');
    expect(market.featureEnabled('properties'), isTrue);
    expect(market.featureEnabled('workers'), isFalse);
    expect(market.featureEnabled('future_feature'), isTrue);
  });

  test('business visit parses authoritative transaction configuration', () {
    final visit = BusinessVisit.fromJson({
      'scan_id': 'scan-1',
      'commission_rate': 10,
      'discount_tiers': [5, 10, 15, 20],
      'member': {
        'user_id': 'member-1',
        'name': 'Member',
        'verified': true,
      },
      'subscription': {'active': true, 'name': 'Premium'},
      'stats': {
        'visits_total': 3,
        'gross_spend_total': 250,
        'discount_saved_total': 25,
        'direct_requests_remaining': 6,
      },
    });

    expect(visit.scanId, 'scan-1');
    expect(visit.verified, isTrue);
    expect(visit.premiumActive, isTrue);
    expect(visit.discountTiers, [0, 5, 10, 15, 20]);
    expect(visit.commissionRate, 10);
    expect(visit.visitsTotal, 3);
  });

  test('lawyer workspace separates available queue from assigned work', () {
    final workspace = LawyerWorkspace.fromJson({
      'lawyer': {'full_name': 'Counsel', 'is_available': true},
      'summary': {
        'available_requests': 2,
        'pending_requests': 1,
      },
      'available_requests': [
        {'id': 'available-1'},
        {'id': 'available-2'},
      ],
      'requests': [
        {'id': 'assigned-1', 'status': 'paid'},
      ],
    });

    expect(workspace.name, 'Counsel');
    expect(workspace.availableRequests, 2);
    expect(workspace.pendingRequests, 1);
    expect(workspace.availableQueue, hasLength(2));
    expect(workspace.requests.single['status'], 'paid');
  });
}
