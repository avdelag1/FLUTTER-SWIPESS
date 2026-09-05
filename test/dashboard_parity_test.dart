import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';

import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';

void main() {
  testWidgets('BentoDashboardScreen renders current search and discovery grid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appMarketProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: Scaffold(body: BentoDashboardScreen())),
      ),
    );

    // Give remote media a moment to load/fail without coupling this test to it.
    await tester.pump(const Duration(seconds: 1));

    // Search lives in the shared AppTopBar, not inside the bento body.
    expect(find.byType(GlowSearchBar), findsNothing);

    expect(find.text('PROPERTIES'), findsWidgets);
    expect(find.text('EVENTS  •  LIVE'), findsWidgets);
    expect(find.text('MOTORCYCLES'), findsWidgets);
    expect(find.text('BICYCLES'), findsWidgets);
    expect(find.text('BUYERS'), findsWidgets);
    expect(find.text('RECOMMENDED FOR YOU'), findsNothing);
  });
}
