import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget host({required Widget child}) {
    return ProviderScope(
      overrides: [
        unreadNotificationsProvider.overrideWith((ref) async => 0),
        tokenBalanceProvider.overrideWith((ref) => 4),
      ],
      child: child,
    );
  }

  testWidgets('profile pill opens via onProfileTap', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      host(
        child: MaterialApp(
          home: Scaffold(
            body: AppTopBar(
              firstName: 'Maya',
              onProfileTap: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('header-profile')));
    await tester.pump();
    expect(opened, isTrue);
    expect(find.text('Maya'), findsNothing);
    expect(find.byKey(const ValueKey('header-profile')), findsOneWidget);
  });

  testWidgets('nested page Scaffold cannot steal the profile tap',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      host(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Scaffold(
                  body: ColoredBox(
                    color: Colors.red,
                    child: SizedBox.expand(),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppTopBar(
                    firstName: 'Maya',
                    onProfileTap: () => opened = true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('header-profile')));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('profile pill go()s to /client/profile when no callback',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/dash',
      routes: [
        GoRoute(
          path: '/dash',
          builder: (_, _) => const Scaffold(
            body: AppTopBar(firstName: 'Maya'),
          ),
        ),
        GoRoute(
          path: AppPaths.clientProfile,
          builder: (_, _) => const Scaffold(
            body: Text('PROFILE PAGE'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      host(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('header-profile')));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE PAGE'), findsOneWidget);
  });

  testWidgets('header icons do not paint radial color glows',
      (tester) async {
    await tester.pumpWidget(
      host(
        child: const MaterialApp(
          home: Scaffold(
            body: AppTopBar(firstName: 'Maya'),
          ),
        ),
      ),
    );
    await tester.pump();

    final radialWashes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((box) {
      final decoration = box.decoration;
      if (decoration is! BoxDecoration) return false;
      final gradient = decoration.gradient;
      if (gradient is! RadialGradient || gradient.colors.isEmpty) {
        return false;
      }
      return true;
    });
    expect(radialWashes, isEmpty);
  });

  testWidgets('create and token controls remain explicit and readable',
      (tester) async {
    await tester.pumpWidget(
      host(
        child: const MaterialApp(
          home: Scaffold(
            body: AppTopBar(firstName: 'Maya'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('header-create')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('header-create')),
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('header-create')),
        matching: find.byIcon(Icons.add_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('header-tokens')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('header-tokens')),
        matching: find.byIcon(Icons.diamond_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('header HUD buttons are thick nexus 48px controls', (tester) async {
    await tester.pumpWidget(
      host(
        child: const MaterialApp(
          home: Scaffold(
            body: AppTopBar(firstName: 'Maya'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(const AppTopBar().preferredSize.height, 72);
    final profile = tester.getSize(find.byKey(const ValueKey('header-profile')));
    expect(profile.height, 42);
    expect(profile.width, 42);
  });

  testWidgets('all header controls fit a compact phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        child: const MaterialApp(
          home: Scaffold(
            body: AppTopBar(firstName: 'Maya'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('header-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('header-create')), findsOneWidget);
    expect(find.byKey(const ValueKey('header-tokens')), findsOneWidget);
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
  });
}
