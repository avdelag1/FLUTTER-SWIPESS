import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
import 'package:flutter_swipes/src/core/widgets/app_notification_bar.dart';

void main() {
  Widget host(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Stack(
          children: [
            ColoredBox(color: Colors.black, child: SizedBox.expand()),
            AppNotificationBar(),
          ],
        ),
      ),
    );
  }

  testWidgets('a banner appears, then clears itself after five seconds', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(host(container));

    container
        .read(appNotificationsProvider.notifier)
        .error(
          'Connection Lost 📱',
          "You're now offline. Some features may be limited.",
        );
    await tester.pump();
    await tester.pump(AppNotificationBar.enterDuration);

    expect(find.text('Connection Lost 📱'), findsOneWidget);
    expect(
      find.text("You're now offline. Some features may be limited."),
      findsOneWidget,
    );

    await tester.pump(AppNotificationBar.visibleDuration);
    await tester.pumpAndSettle();
    expect(find.text('Connection Lost 📱'), findsNothing);
    expect(container.read(appNotificationsProvider), isEmpty);
  });

  testWidgets('the close button dismisses it early', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(host(container));

    container
        .read(appNotificationsProvider.notifier)
        .info('Back Online! 🌐', 'Your connection has been restored.');
    await tester.pump();
    await tester.pump(AppNotificationBar.enterDuration);
    expect(find.text('Back Online! 🌐'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Back Online! 🌐'), findsNothing);
  });

  testWidgets('a queued banner follows the one before it', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(host(container));

    final notifier = container.read(appNotificationsProvider.notifier);
    notifier.error('Connection Lost 📱');
    await tester.pump();
    await tester.pump(AppNotificationBar.enterDuration);
    notifier.info('Back Online! 🌐');
    await tester.pump();

    // Still showing the first one; the second waits its turn.
    expect(find.text('Back Online! 🌐'), findsNothing);

    await tester.pump(AppNotificationBar.visibleDuration);
    await tester.pumpAndSettle();
    expect(find.text('Back Online! 🌐'), findsOneWidget);
  });

  group('AppNotificationsNotifier (Cap notificationStore)', () {
    test('drops a repeat inside the ten second window', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appNotificationsProvider.notifier);

      notifier.error('Connection Lost 📱', 'flapping');
      notifier.error('Connection Lost 📱', 'flapping');
      expect(container.read(appNotificationsProvider), hasLength(1));

      notifier.info('Back Online! 🌐', 'flapping');
      expect(container.read(appNotificationsProvider), hasLength(2));
    });

    test('keeps at most twenty queued', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appNotificationsProvider.notifier);

      for (var i = 0; i < 25; i++) {
        notifier.info('Notice $i');
      }
      expect(container.read(appNotificationsProvider), hasLength(20));
      // Newest first, like Cap.
      expect(container.read(appNotificationsProvider).first.title, 'Notice 24');
    });
  });
}
