import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

void main() {
  testWidgets('Auth screen displays login form', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authIntentProvider.overrideWith(() => AuthIntentNotifier()..set(AuthIntent.login)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AuthScreen()),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('LOG IN'), findsWidgets);
  });
}
