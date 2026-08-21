import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ModalRoute currentness changes while a full-screen child route is pushed',
    (tester) async {
      bool? underlyingIsCurrent;

      await tester.pumpWidget(
        MaterialApp(
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

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(underlyingIsCurrent, isTrue);
    },
  );

  test('DashboardShell gates every persistent chrome layer by route currentness', () {
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
      contains(
        'final persistentChromeVisible = showChrome && shellRouteIsCurrent;',
      ),
    );
    expect(source, contains('ignoring: !persistentChromeVisible'));
    expect(source, contains('visible: persistentChromeVisible'));
    expect(source, contains('user != null && shellRouteIsCurrent'));
  });

  test('Settings hierarchy keeps its own safe, scrollable top controls', () {
    for (final path in <String>[
      'lib/src/features/profile/presentation/screens/settings_screen.dart',
      'lib/src/features/profile/presentation/screens/security_screen.dart',
      'lib/src/features/profile/presentation/screens/about_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('SafeArea('), reason: '$path must honor device insets');
      expect(
        source.contains('ListView(') ||
            source.contains('SingleChildScrollView(') ||
            source.contains('CustomScrollView('),
        isTrue,
        reason: '$path must remain vertically reachable on small phones',
      );
      expect(
        source.contains('Navigator.pop(context)') ||
            source.contains('CapBackButton'),
        isTrue,
        reason: '$path must expose an independent back control',
      );
    }
  });
}
