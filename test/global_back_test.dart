import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/routing/global_back_dispatcher.dart';
import 'package:flutter_swipes/src/core/routing/section_navigation.dart';

void main() {
  group('SectionNavigation.parentRoute (Cap sectionNavigation.ts)', () {
    test('dashboard roots exit the app', () {
      expect(SectionNavigation.parentRoute(AppPaths.clientDashboard), isNull);
      expect(SectionNavigation.parentRoute(AppPaths.ownerDashboard), isNull);
      expect(SectionNavigation.parentRoute(AppPaths.legacyDashboard), isNull);
      expect(SectionNavigation.parentRoute('/'), isNull);
    });

    test('pre-auth screens hand the press to the platform', () {
      expect(SectionNavigation.parentRoute(AppPaths.gate), isNull);
      expect(SectionNavigation.parentRoute(AppPaths.welcome), isNull);
      expect(SectionNavigation.parentRoute(AppPaths.auth), isNull);
      expect(SectionNavigation.parentRoute(AppPaths.onboarding), isNull);
    });

    test('a section home goes up to the dashboard', () {
      expect(
        SectionNavigation.parentRoute(AppPaths.messages),
        AppPaths.clientDashboard,
      );
      expect(
        SectionNavigation.parentRoute(AppPaths.clientSettings),
        AppPaths.clientDashboard,
      );
      expect(
        SectionNavigation.parentRoute(AppPaths.documents),
        AppPaths.clientDashboard,
      );
    });

    test('a page inside a section goes up to that section home', () {
      expect(
        SectionNavigation.parentRoute('/messages/conversation-42'),
        AppPaths.messages,
      );
      expect(
        SectionNavigation.parentRoute('/explore/events/tulum-sunset'),
        AppPaths.exploreEvents,
      );
      expect(
        SectionNavigation.parentRoute(AppPaths.ownerListingsNew),
        AppPaths.clientDashboard,
      );
    });

    test('the longest matching section wins', () {
      // `/client/legal-services` must not resolve to the `/client/legal` root.
      expect(
        SectionNavigation.sectionRoot(AppPaths.clientLegalServices),
        AppPaths.clientLegalServices,
      );
      expect(
        SectionNavigation.sectionRoot('/explore/events/likes'),
        AppPaths.exploreEvents,
      );
    });

    test('unmapped routes fall back to the dashboard, never a dead end', () {
      expect(
        SectionNavigation.parentRoute('/listing/42'),
        AppPaths.clientDashboard,
      );
      expect(
        SectionNavigation.parentRoute('/who-knows/what'),
        AppPaths.clientDashboard,
      );
    });

    test('trailing slashes and query strings normalize', () {
      expect(SectionNavigation.parentRoute('/client/dashboard/'), isNull);
      expect(
        SectionNavigation.parentRoute('/messages/?filter=unread'),
        AppPaths.clientDashboard,
      );
    });
  });

  group('GlobalBackButtonDispatcher', () {
    late GoRouter router;
    late ProviderContainer container;

    Widget buildApp() {
      router = GoRouter(
        initialLocation: AppPaths.clientDashboard,
        routes: [
          GoRoute(
            path: AppPaths.clientDashboard,
            builder: (_, _) => const Text('dashboard'),
          ),
          GoRoute(
            path: AppPaths.messages,
            builder: (_, _) => const Text('messages'),
          ),
          GoRoute(
            path: '/messages/:id',
            builder: (_, _) => const Text('thread'),
          ),
          GoRoute(
            path: AppPaths.clientSettings,
            builder: (_, _) => const Text('settings'),
          ),
        ],
      );
      container = ProviderContainer(
        overrides: [appRouterProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          backButtonDispatcher: container.read(
            globalBackButtonDispatcherProvider,
          ),
        ),
      );
    }

    String location() => router.state.uri.path;

    testWidgets('walks up from a section page to the section home', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      router.go('/messages/thread-7');
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(location(), AppPaths.messages);
    });

    testWidgets('walks up from a section home to the dashboard', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      router.go(AppPaths.clientSettings);
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(location(), AppPaths.clientDashboard);
    });

    testWidgets('lets the platform close the app on the dashboard root', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isFalse);
      expect(location(), AppPaths.clientDashboard);
    });

    testWidgets('pops a pushed route before walking up', (tester) async {
      await tester.pumpWidget(buildApp());
      router.go(AppPaths.messages);
      await tester.pumpAndSettle();
      router.push(AppPaths.clientSettings);
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(location(), AppPaths.messages);
    });

    testWidgets('closes an open overlay first and keeps the route', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      router.go(AppPaths.clientSettings);
      await tester.pumpAndSettle();
      container.read(overlayModalsProvider.notifier).openConcierge('hola');
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(container.read(overlayModalsProvider).showConcierge, isFalse);
      expect(location(), AppPaths.clientSettings);
    });
  });
}
