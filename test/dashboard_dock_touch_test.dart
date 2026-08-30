import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/dashboard_dock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every dock button responds to a 44pt touch target', (tester) async {
    for (final item in defaultDashboardNavItems) {
      NavTab? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: DockButton(
                item: item,
                wash: item.wash,
                selected: false,
                onTap: () => tapped = item.id,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(DockButton)), const Size(44, 44));
      await tester.tap(find.byType(DockButton));
      await tester.pump();
      expect(tapped, item.id, reason: '${item.id} did not react to touch');
    }
  });

  testWidgets('events and lawyers remain tappable across dock scrolling', (
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

    // Events intentionally lives near the front of the current dock ordering.
    await tester.tap(find.byIcon(Icons.celebration_rounded));
    await tester.pump();
    expect(tapped, NavTab.events);

    // Lawyers lives later in the horizontal dock and must remain reachable after
    // scrolling without a neighboring button stealing the hit target.
    final scroller = find.byType(SingleChildScrollView);
    expect(scroller, findsOneWidget);
    await tester.drag(scroller, const Offset(-280, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.balance_rounded));
    await tester.pump();
    expect(tapped, NavTab.legal);
  });
}
