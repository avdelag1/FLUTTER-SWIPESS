import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/legal/data/legal_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_intake.dart';

void main() {
  test('intake status helpers follow request → offer → pay → schedule', () {
    final waiting = LegalIntake.fromJson({
      'id': 'a',
      'status': 'pending',
      'package_name': 'Lease review',
    });
    expect(waiting.isWaiting, isTrue);
    expect(waiting.canPay, isFalse);
    expect(waiting.canJoinCall, isFalse);
    expect(waiting.headline, 'Lease review');
    expect(waiting.statusLabel, 'Waiting for a lawyer');

    final offered = LegalIntake.fromJson({
      'id': 'b',
      'status': 'offered',
      'quoted_price': 149,
    });
    expect(offered.canPay, isTrue);
    expect(offered.canCancel, isTrue);

    final scheduled = LegalIntake.fromJson({
      'id': 'c',
      'status': 'scheduled',
      'consult_at': '2026-08-23T18:00:00Z',
    });
    expect(scheduled.canJoinCall, isTrue);
    expect(scheduled.canPay, isFalse);
  });

  test('consult rooms are stable and paypal checkout is web, not Apple', () {
    expect(
      LegalRepository.consultRoom('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'),
      'SwipessLegal-aaaaaaaabbbbcccc',
    );
    final paypal = LegalRepository.paypalCheckout(
      itemName: 'Lease review',
      amount: 149,
    );
    expect(paypal.host, 'www.paypal.com');
    expect(paypal.queryParameters['amount'], '149.00');
    expect(paypal.queryParameters['item_name'], 'Lease review');
  });
}
