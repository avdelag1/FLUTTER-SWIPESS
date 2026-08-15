import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/concierge_sheet_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Intel Core card slides up and keeps chat when MENU is tapped', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ConciergeSheetHost(
              onClose: () => closed = true,
              child: const ColoredBox(
                color: Color(0xFF111111),
                child: Center(child: Text('CHAT BODY')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHAT BODY'), findsOneWidget);
    expect(find.text('MENU'), findsOneWidget);
    expect(find.byType(PopupMenuButton), findsNothing);

    await tester.tap(find.text('MENU'));
    await tester.pumpAndSettle();

    expect(find.text('CHAT BODY'), findsOneWidget);
    expect(find.text('MENU'), findsNothing);
    expect(closed, isFalse);
  });

  testWidgets('Intel Core card is bounded and does not overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const ProviderScope(child: _HostApp()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('CHAT BODY'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  test('opening the map keeps an open concierge session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(overlayModalsProvider.notifier).openConcierge('hello');
    container.read(overlayModalsProvider.notifier).openPassportMap();
    final state = container.read(overlayModalsProvider);
    expect(state.showConcierge, isTrue);
    expect(state.conciergeQuery, 'hello');
    expect(state.showPassportMap, isTrue);
  });
}

class _HostApp extends StatelessWidget {
  const _HostApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ConciergeSheetHost(
          onClose: () {},
          child: const ColoredBox(
            color: Color(0xFF111111),
            child: Center(child: Text('CHAT BODY')),
          ),
        ),
      ),
    );
  }
}
