import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/app.dart';
import 'package:flutter_swipes/src/core/session/session_controller.dart';
import 'package:flutter_swipes/src/features/access/presentation/screens/access_code_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('access gate shows secret code entry', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AccessCodeScreen())),
    );
    await tester.pump();

    expect(find.text('Enter Access Code'), findsOneWidget);
    expect(find.text('Authorized access only'), findsOneWidget);
    expect(find.text('Enter'), findsOneWidget);
    expect(find.text("Don't have a code? Request one"), findsOneWidget);
  });

  testWidgets('welcome screen shows sign in and create account', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WelcomeScreen())),
    );
    await tester.pump();

    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets('auth screen shows apple and google options', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );
    await tester.pump();

    expect(find.text('SIGN IN WITH APPLE'), findsOneWidget);
    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets('dashboard shows category deck and HUD', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PROPERTIES'), findsWidgets);
    expect(find.text('ENGAGE DISCOVERY'), findsWidgets);
    expect(find.text('EVENTS'), findsOneWidget);
  });

  testWidgets('app opens on the access gate', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NativeSwipeApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Enter Access Code'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);
  });

  testWidgets('valid access code unlocks welcome', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NativeSwipeApp()));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'URDBEST');
    await tester.tap(find.text('Enter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  test('session notifier grants access and signs in', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sessionProvider).accessGranted, isFalse);
    container.read(sessionProvider.notifier).grantAccess();
    expect(container.read(sessionProvider).accessGranted, isTrue);

    container.read(sessionProvider.notifier).signInDemo(name: 'Maya');
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(container.read(sessionProvider).displayName, 'Maya');
  });
}
