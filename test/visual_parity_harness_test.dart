import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';

import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

void main() {
  setUp(() {
    // Disable external image fetching
  });

  Future<void> pumpScreen(WidgetTester tester, Widget child, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Mock auth state
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Visual Parity Goldens', () {
    const sizes = {
      'mobile': Size(390, 844),
      'desktop': Size(1440, 900),
    };

    for (final entry in sizes.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('access_code_gate - $name', (tester) async {
        await pumpScreen(tester, const AccessCodeGateScreen(), size: size);
        await expectLater(
          find.byType(AccessCodeGateScreen),
          matchesGoldenFile('goldens/access_code_gate_$name.png'),
        );
      });

      testWidgets('welcome - $name', (tester) async {
        await pumpScreen(tester, const WelcomeScreen(), size: size);
        await expectLater(
          find.byType(WelcomeScreen),
          matchesGoldenFile('goldens/welcome_$name.png'),
        );
      });

      testWidgets('auth - $name', (tester) async {
        await pumpScreen(tester, const AuthScreen(), size: size);
        await expectLater(
          find.byType(AuthScreen),
          matchesGoldenFile('goldens/auth_$name.png'),
        );
      });

      testWidgets('dashboard - $name', (tester) async {
        await pumpScreen(tester, const DashboardShell(child: SizedBox()), size: size);
        await expectLater(
          find.byType(DashboardShell),
          matchesGoldenFile('goldens/dashboard_$name.png'),
        );
      });
      
      testWidgets('swipe - $name', (tester) async {
        await pumpScreen(tester, const ClientSwipeContainer(), size: size);
        await expectLater(
          find.byType(ClientSwipeContainer),
          matchesGoldenFile('goldens/swipe_$name.png'),
        );
      });
    }
  });
}
