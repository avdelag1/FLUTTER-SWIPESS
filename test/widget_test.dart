// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_swipes/src/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: NativeSwipeApp()));

    // MaterialApp.router resolves the initial GoRouter route asynchronously, so
    // let the widget tree settle before asserting on the rendered screen.
    await tester.pumpAndSettle();

    // Verify that the title is present.
    expect(find.text('Discover'), findsOneWidget);
  });
}
