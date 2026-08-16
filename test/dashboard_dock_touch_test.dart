import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/dashboard_dock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home, lawyers and events dock buttons all react to touch', (
    tester,
  ) async {
    NavTab? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: DashboardDock(
              items: defaultDashboardNavItems,
              selectedTab: NavTab.dashboard,
              onTabSelected: (tab) => tapped = tab,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.home_rounded));
    expect(tapped, NavTab.dashboard);

    final list = find.byType(ListView);
    await tester.drag(list, const Offset(-280, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.balance_rounded));
    expect(tapped, NavTab.legal);

    await tester.tap(find.byIcon(Icons.event_rounded));
    expect(tapped, NavTab.events);
  });
}
