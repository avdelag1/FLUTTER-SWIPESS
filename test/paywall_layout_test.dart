import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/paywall_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('three month promo stays centered and paywall needs no scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: PaywallScreen(featureName: 'Events'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('3 MONTHS FREE ACCESS'), findsOneWidget);
    expect(find.text('Package 1'), findsOneWidget);
    expect(find.text('Package 2'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall-view-packages')), findsOneWidget);

    final promoCenter = tester.getCenter(
      find.byKey(const ValueKey('three-month-promo')),
    );
    expect((promoCenter.dx - 160).abs(), lessThan(2));
  });
}
