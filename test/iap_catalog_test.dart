import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/config/supabase_config.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    }
  });

  test('catalog keeps the live store product IDs', () {
    expect(
      IapCatalog.tokens.map((offer) => offer.id),
      containsAll(<String>{
        'Swipess.tokens.20.v2',
        'Swipess.tokens.50.v2',
        'Swipess.tokens.100.v2',
        'Swipess.tokens.150.v2',
      }),
    );
    expect(
      IapCatalog.subscriptions.map((offer) => offer.id),
      containsAll(<String>{
        'Swipess.premium.monthly',
        'Swipess.premium.6months',
        'Swipess.premium.unlimited',
      }),
    );
    expect(
      IapCatalog.eventPromotions.map((offer) => offer.id),
      containsAll(<String>{
        'Swipess.event_24h',
        'Swipess.event_3d',
        'Swipess.event_7d',
      }),
    );
  });

  test('PayPal NCP suffixes remain unchanged', () {
    expect(
      IapCatalog.tokens.map((offer) => offer.paypalSuffix),
      containsAll(<String>{
        '2FV90084FG8548511',
        '7GX20366U9697820L',
        '8BR474487P617742N',
        '6M87362919089383F',
      }),
    );
    expect(
      IapCatalog.subscriptions.map((offer) => offer.paypalSuffix),
      containsAll(<String>{
        '6UV37038NL760862E',
        '85K21645YN369951P',
        '3D9060752M197524D',
      }),
    );
  });

  test('paypalUrl is never exposed on native iOS (Guideline 3.1.1)', () {
    for (final offer in [
      ...IapCatalog.tokens,
      ...IapCatalog.subscriptions,
      ...IapCatalog.eventPromotions,
    ]) {
      expect(offer.paypalUrlForPlatform(isIos: true), isNull);
    }
  });

  test('paypalUrl builds NCP links off iOS', () {
    final offer = IapCatalog.tokens.first;
    expect(
      offer.paypalUrlForPlatform(isIos: false).toString(),
      contains('paypal.com/ncp/payment/${offer.paypalSuffix}'),
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
