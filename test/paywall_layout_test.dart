import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/paywall_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('current membership paywall fits a compact phone without scrolling', (
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
    expect(find.text('Continue with Events'), findsOneWidget);
    expect(find.textContaining('complimentary access has ended'), findsOneWidget);
    expect(find.text('MONTHLY'), findsOneWidget);
    expect(find.text('SEMI-ANNUAL'), findsOneWidget);
    expect(find.text('YEARLY'), findsOneWidget);
    expect(find.text('HERE NOW'), findsOneWidget);
    expect(find.text('LIVE LOCAL'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall-view-packages')), findsOneWidget);
  });
}
