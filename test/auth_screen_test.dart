import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Auth screen displays login form', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/auth?mode=login',
      routes: [
        GoRoute(
          path: '/auth',
          builder: (context, state) => AuthScreen(
            mode: state.uri.queryParameters['mode'] ?? 'login',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authIntentProvider.overrideWith(
            () => AuthIntentNotifier()..set(AuthIntent.login),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('LOG IN'), findsWidgets);
  });

  testWidgets('Auth route restores email confirmation state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/auth?mode=login&confirm=created',
      routes: [
        GoRoute(
          path: '/auth',
          builder: (context, state) => AuthScreen(
            mode: state.uri.queryParameters['mode'] ?? 'login',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('GO TO SIGN IN'), findsOneWidget);
  });
}
