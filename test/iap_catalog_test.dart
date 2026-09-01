import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Supabase Flutter stores its auth session through SharedPreferences on
    // mobile. Production has the plugin; isolated widget tests need the mock
    // channel before Supabase is initialized.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('catalog keeps the live store product IDs', () {
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
    expect(IapCatalog.tokens.first.description, '20 Direct Requests');
    expect(IapCatalog.subscriptions.where((o) => o.isSubscription).length, 3);
    expect(IapCatalog.tokens.first.isSubscription, isFalse);
  });

  test('PayPal NCP suffixes remain unchanged', () {
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
  });

  test('paypalUrl is never exposed on native iOS (Guideline 3.1.1)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(IapCatalog.paypalUrl('QSRXCJYYQ2UGY'), isNull);
    expect(IapCatalog.paypalUrl(null), isNull);
    expect(IapCatalog.paypalUrl(''), isNull);
  });

  test('paypalUrl builds NCP links off iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      IapCatalog.paypalUrl('VNM2QVBFG6TA4'),
      'https://www.paypal.com/ncp/payment/VNM2QVBFG6TA4',
    );
  });

  test('CheckoutResult keeps native payment outcomes', () {
    expect(CheckoutResult.purchased.isSuccess, isTrue);
    expect(CheckoutResult.restored.isSuccess, isTrue);
    expect(CheckoutResult.openedWebCheckout.isSuccess, isFalse);
  });

  testWidgets('tokens modal explains Direct Requests', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directRequestBalanceProvider.overrideWith(
            (ref) async => const DirectRequestBalance(
              total: 20,
              reserved: 2,
              available: 18,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TokensModal())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DIRECT REQUESTS'), findsWidgets);
    // Package cards intentionally style the count and label separately.
    expect(find.text('20'), findsWidgets);
    expect(find.text('\$9.99'), findsOneWidget);
    expect(
      find.textContaining('reserved token returns automatically'),
      findsOneWidget,
    );
  });
}
