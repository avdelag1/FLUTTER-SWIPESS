import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The swipe deck used to collapse to 0×0 while chrome was visible:
/// ChromeSummonZones becomes a [SizedBox.shrink], and a loose [Stack]
/// then sizes to that child. Cards never painted.
void main() {
  const cardKey = ValueKey('swipe-card-well');

  testWidgets('expanded stack still paints a fill child next to a shrink', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ColoredBox(
                  key: cardKey,
                  color: Color(0xFFFF0000),
                  child: SizedBox.expand(child: Text('CARD')),
                ),
              ),
              Positioned(top: 0, left: 0, child: Text('HDR')),
              SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );

    final card = tester.getSize(find.byKey(cardKey));
    expect(card.height, greaterThan(200));
    expect(card.width, greaterThan(200));
    expect(find.text('CARD'), findsOneWidget);
  });

  testWidgets('loose stack collapses when the only loose child is shrink', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(key: cardKey, color: Color(0xFFFF0000)),
                ),
                SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );

    final card = tester.getSize(find.byKey(cardKey));
    expect(card.height, 0);
    expect(card.width, 0);
  });
}
