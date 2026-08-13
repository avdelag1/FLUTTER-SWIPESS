import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Welcome screen shows Sign In and Create Account only',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'swipess_legendary_onboarding_done': true,
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('ENTER APP'), findsNothing);
  });
}
