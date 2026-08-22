import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';

void main() {
  testWidgets('BentoDashboardScreen renders current search and discovery grid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: BentoDashboardScreen())),
      ),
    );

    // Give remote media a moment to load/fail without coupling this test to it.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('What are you looking for?'), findsOneWidget);
    expect(find.text('PROPERTIES'), findsWidgets);
    expect(find.text('EVENTS LIVE'), findsWidgets);
    expect(find.text('WORKERS'), findsWidgets);
    expect(find.text('RECOMMENDED FOR YOU'), findsWidgets);
  });
}
