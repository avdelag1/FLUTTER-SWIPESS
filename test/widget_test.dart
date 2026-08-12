import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Welcome screen shows Sign In and Create Account', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });
}
