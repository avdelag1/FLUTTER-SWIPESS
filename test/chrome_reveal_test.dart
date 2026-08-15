import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/chrome_reveal_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/chrome_summon_zones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('swipe chrome hides after seven seconds and top tap restores it',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: _ChromeLifecycleHost()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-chrome-timer')));
    await tester.pump();
    expect(find.text('visible'), findsOneWidget);

    await tester.pump(
      const Duration(milliseconds: ChromeRevealNotifier.chromeHideMs + 1),
    );
    expect(find.text('hidden'), findsOneWidget);

    await tester.tapAt(const Offset(160, 20));
    await tester.pump();
    expect(find.text('visible'), findsOneWidget);
  });
}

class _ChromeLifecycleHost extends ConsumerWidget {
  const _ChromeLifecycleHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(chromeRevealProvider);
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(chrome.chromeVisible ? 'visible' : 'hidden'),
                FilledButton(
                  key: const ValueKey('start-chrome-timer'),
                  onPressed: () =>
                      ref.read(chromeRevealProvider.notifier).reveal(),
                  child: const Text('Start'),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: ChromeSummonZones(
              visible: chrome.chromeVisible,
              onSummon: () =>
                  ref.read(chromeRevealProvider.notifier).reveal(),
            ),
          ),
        ],
      ),
    );
  }
}
