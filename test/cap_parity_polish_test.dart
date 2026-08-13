import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/widgets/pulse_feed_states.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_match_meter.dart';

void main() {
  testWidgets('Pulse Feed empty state is visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PulseFeedEmpty()),
      ),
    );
    expect(find.text('SILENCE IS GOLDEN'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });

  testWidgets('SwipeMatchMeter hides at 0 and shows percent when matching',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SwipeMatchMeter(percentage: 0),
              SwipeMatchMeter(percentage: 88),
            ],
          ),
        ),
      ),
    );
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });
}
