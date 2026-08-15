import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';

void main() {
  testWidgets('BentoDashboardScreen renders search, chips, and grid', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BentoDashboardScreen(),
          ),
        ),
      ),
    );

    // Give images time to load/fail
    await tester.pumpAndSettle();

    // Verify search bar exists (case-sensitive)
    expect(find.text('SEARCH ASSETS...'), findsOneWidget); 
    
    // Verify chips exist
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Pros'), findsOneWidget);

    // Verify bento grid elements exist
    expect(find.text('EVENTS LIVE'), findsWidgets);
    expect(find.text('PROPERTIES'), findsWidgets);
  });
}
