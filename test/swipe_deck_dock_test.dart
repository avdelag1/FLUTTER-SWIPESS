import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows all five icons and routes chat to messages', (tester) async {
    var aiTaps = 0;
    var messageTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeDeckDock(
            onDashboard: () {},
            onTokens: () {},
            onAi: () => aiTaps++,
            onAdd: () {},
            onMessages: () => messageTaps++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.diamond_rounded), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe-deck-dock')), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe-dock-dashboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe-dock-tokens')), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe-dock-ai')), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe-dock-create')), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe-dock-messages')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
    await tester.pump();

    expect(messageTaps, 1);
    expect(aiTaps, 0);
  });
}
