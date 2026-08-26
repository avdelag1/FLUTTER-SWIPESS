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
          appMarketProvider.overrideWith((ref) => const AsyncValue.data(null)),
        ],
        child: const MaterialApp(home: Scaffold(body: BentoDashboardScreen())),
      ),
    );

    // Give remote media a moment to load/fail without coupling this test to it.
    await tester.pump(const Duration(seconds: 1));

    // The tap-only GlowSearchBar rotates visible prompts, so inspect the
    // canonical configured hint instead of freezing the test to one frame of
    // its animation.
    expect(find.byType(GlowSearchBar), findsOneWidget);
    final search = tester.widget<GlowSearchBar>(find.byType(GlowSearchBar));
    expect(search.hint, 'What are you looking for?');

    expect(find.text('PROPERTIES'), findsWidgets);
    expect(find.text('EVENTS  •  LIVE'), findsWidgets);
    expect(find.text('WORKERS'), findsWidgets);
    expect(find.text('RECOMMENDED FOR YOU'), findsWidgets);
  });
}
