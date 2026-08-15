import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('catalog keeps the live Cap App Store product IDs', () {
    expect(IapCatalog.subscriptions.map((o) => o.appleProductId).toList(), [
      'Swipess.plus.monthly.v3',
      'Swipess.plus.semestral.v3',
      'Swipess.plus.annual.v3',
    ]);
    expect(IapCatalog.tokens.map((o) => o.appleProductId).toList(), [
      'Swipess.tokens.20.v2',
      'Swipess.tokens.50.v2',
      'Swipess.tokens.100.v2',
      'Swipess.tokens.150.v2',
    ]);
    expect(IapCatalog.eventPromos.map((o) => o.appleProductId).toList(), [
      'Swipess.promo.event.week.v3',
      'Swipess.promo.event.month.v3',
      'Swipess.promo.event.quarter.v3',
    ]);
    expect(IapCatalog.tokenById('plus')?.tokens, 50);
    expect(
      IapCatalog.promoById('growth')?.appleProductId,
      'Swipess.promo.event.month.v3',
    );
    expect(IapCatalog.subscriptions.where((o) => o.isSubscription).length, 3);
    expect(IapCatalog.tokens.first.isSubscription, isFalse);
  });

  test('PayPal NCP suffixes match Cap iapProducts / AdvertisePage', () {
    expect(IapCatalog.subscriptions.map((o) => o.paypalPath).toList(), [
      'QSRXCJYYQ2UGY',
      'HUESWJ68BRUSY',
      '7E6R38L33LYUJ',
    ]);
    expect(IapCatalog.tokens.map((o) => o.paypalPath).toList(), [
      'VNM2QVBFG6TA4',
      'VG2C7QMAC8N6A',
      '9NBGA9X3BJ5UA',
      'KP9WHGEN23MYA',
    ]);
    expect(IapCatalog.eventPromos.map((o) => o.paypalPath).toList(), [
      'ZXQC96VYV7JLL',
      'ATKD4TR7KFTJU',
      'LK7XWSMDHH8AW',
    ]);
  });

  test('paypalUrl is never exposed on native iOS (Guideline 3.1.1)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(IapCatalog.paypalUrl('QSRXCJYYQ2UGY'), isNull);
    expect(IapCatalog.paypalUrl(null), isNull);
    expect(IapCatalog.paypalUrl(''), isNull);
  });

  test('paypalUrl builds Cap NCP links off iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      IapCatalog.paypalUrl('VNM2QVBFG6TA4'),
      'https://www.paypal.com/ncp/payment/VNM2QVBFG6TA4',
    );
  });

  test('CheckoutResult copy matches Cap orchestrator outcomes', () {
    expect(CheckoutResult.purchased.isSuccess, isTrue);
    expect(CheckoutResult.restored.isSuccess, isTrue);
    expect(CheckoutResult.openedWebCheckout.isSuccess, isFalse);
    expect(CheckoutResult.openedWebCheckout.userMessage, contains('PayPal'));
    expect(CheckoutResult.unavailable.userMessage, contains('App Store'));
  });

  testWidgets('tokens modal lists Cap packs and PayPal web copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: TokensModal())),
      ),
    );
    expect(find.text('20 Tokens'), findsOneWidget);
    expect(find.text('50 Tokens'), findsOneWidget);
    expect(find.text('\$9.99'), findsOneWidget);
    expect(find.text('\$19.99'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
  });
}
