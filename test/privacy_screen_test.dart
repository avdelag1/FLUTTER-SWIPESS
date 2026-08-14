import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/native/privacy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  setUp(() {
    calls.clear();
    PrivacyScreen.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PrivacyScreen.channel, (call) async {
      calls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PrivacyScreen.channel, null);
  });

  testWidgets('a protected surface turns protection on and off with its life',
      (tester) async {
    await tester.pumpWidget(
      const PrivacyScreenGuard(child: SizedBox.shrink()),
    );
    await tester.pump();
    expect(calls, ['enable']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls, ['enable', 'disable']);
  });

  testWidgets('nested protected surfaces do not unprotect each other',
      (tester) async {
    await tester.pumpWidget(
      const PrivacyScreenGuard(
        child: PrivacyScreenGuard(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    // The vault opening the ID card on top of itself must not ask twice.
    expect(calls, ['enable']);
    expect(PrivacyScreen.holders, 2);

    await tester.pumpWidget(
      const PrivacyScreenGuard(child: SizedBox.shrink()),
    );
    await tester.pump();
    // Inner surface closed, outer one still open — stay protected.
    expect(calls, ['enable']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls, ['enable', 'disable']);
    expect(PrivacyScreen.holders, 0);
  });

  test('a host without the channel is a no-op, not a crash', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PrivacyScreen.channel, null);
    await expectLater(PrivacyScreen.enable(), completes);
    await expectLater(PrivacyScreen.disable(), completes);
  });
}
