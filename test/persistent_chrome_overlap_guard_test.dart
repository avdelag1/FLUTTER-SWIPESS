import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ModalRoute currentness changes while a full-screen child route is pushed',
    (tester) async {
      bool? underlyingIsCurrent;
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) {
              underlyingIsCurrent = ModalRoute.of(context)?.isCurrent;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(body: Text('child')),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(underlyingIsCurrent, isTrue);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(underlyingIsCurrent, isFalse);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(underlyingIsCurrent, isTrue);
    },
  );

  test('DashboardShell gates persistent chrome and summon paths by route currentness', () {
    final source = File(
      'lib/src/features/dashboard/presentation/screens/dashboard_shell.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'final shellRouteIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;',
      ),
    );
    expect(
      source,
      contains('chromeOpacity > 0.01 && (shellRouteIsCurrent || headerMenuOpen)'),
      reason:
          'Profile and other shell pages must share the scroll-hide contract',
    );
    expect(
      source,
      isNot(contains('final persistentChromeVisible = isProfile')),
      reason: 'Profile must not force header/dock visible while scrolling',
    );
    expect(source, contains('ignoring: !persistentChromeVisible'));
    expect(
      source,
      contains('persistentChromeVisible ||'),
      reason: 'Summon zones stay disabled whenever chrome is already visible',
    );
    expect(
      source,
      contains('isProfile ||'),
      reason: 'Sticky/profile routes must not arm immersive summon zones',
    );
    expect(source, contains('!_chromeMayAutoHide(location)'));
    expect(
      source,
      contains('if (shellRouteIsCurrent)'),
      reason: 'A covered shell route must never summon its chrome over a child route',
    );
    expect(source, contains('user != null && shellRouteIsCurrent'));
  });

  test('Requests and Messages reserve shared chrome while Events uses timed reveal', () {
    final shell = File(
      'lib/src/features/dashboard/presentation/screens/dashboard_shell.dart',
    ).readAsStringSync();
    final events = File(
      'lib/src/features/events/presentation/screens/events_screen.dart',
    ).readAsStringSync();
    final opener = File(
      'lib/src/features/events/presentation/utils/open_events_feed.dart',
    ).readAsStringSync();

    expect(shell, contains('final needsPersistentChromeInsets ='));
    expect(shell, contains('location == AppPaths.messages'));
    expect(shell, contains('location == AppPaths.exploreSeekers'));
    expect(shell, contains('needsPersistentChromeInsets'));
    expect(shell, isNot(contains('!isEvents && chromeOpacity')));
    expect(
      shell,
      contains('isEvents ||'),
      reason: 'Events must disable shell summon zones so only its eye control changes both chrome layers',
    );

    expect(
      events,
      contains('static const _chromeTimeout = Duration(seconds: 6);'),
    );
    expect(events, contains('_chromeVisible = true;'));
    expect(events, contains('_showChrome();'));
    expect(opener, contains('chromeVisibilityProvider.notifier).show()'));
  });

  test('Settings hierarchy keeps its own safe, scrollable top controls', () {
    for (final path in <String>[
      'lib/src/features/profile/presentation/screens/settings_screen.dart',
      'lib/src/features/profile/presentation/screens/security_screen.dart',
      'lib/src/features/profile/presentation/screens/about_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('SafeArea('),
        reason: '$path must honor device insets',
      );
      expect(
        source.contains('ListView(') ||
            source.contains('SingleChildScrollView(') ||
            source.contains('CustomScrollView('),
        isTrue,
        reason: '$path must remain vertically reachable on small phones',
      );
      expect(
        source.contains('Navigator.pop(context)') ||
            source.contains('Navigator.of(context).pop()') ||
            source.contains('Navigator.of(context).pop();') ||
            source.contains('context.pop()') ||
            source.contains('CapBackButton'),
        isTrue,
        reason: '$path must expose an independent back control',
      );
    }
  });
}
