import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/native/app_lifecycle_service.dart';
import 'package:flutter_swipes/src/core/native/local_notifications_service.dart';

class _RecordingNotifications extends LocalNotificationsService {
  final calls = <String>[];

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  Future<void> scheduleReengagement() async => calls.add('schedule');

  @override
  Future<void> cancelReengagement() async => calls.add('cancel');
}

void main() {
  late _RecordingNotifications service;
  late ProviderContainer container;

  Widget host() {
    service = _RecordingNotifications();
    container = ProviderContainer(
      overrides: [localNotificationsProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: AppLifecycleWatcher(child: SizedBox.shrink()),
      ),
    );
  }

  testWidgets('mounting clears anything pending — the user is here now', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(service.calls, ['initialize', 'cancel']);
  });

  testWidgets('backgrounding schedules the nudges, returning clears them', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    service.calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(service.calls, ['schedule']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.calls, ['schedule', 'cancel']);
  });

  test('a tapped reminder routes to the notifications feed', () async {
    final routed = <String>[];
    final plain = LocalNotificationsService()..onNotificationRoute = routed.add;

    plain.handleTapForTest(null);
    plain.handleTapForTest('/messages/42');
    plain.handleTapForTest('listing/7');

    expect(routed, ['/notifications', '/messages/42', '/listing/7']);
  });

  test('Cap reminder ids are preserved so old schedules still cancel', () {
    expect(LocalNotificationsService.reengageIds, [88001, 88002]);
  });
}
