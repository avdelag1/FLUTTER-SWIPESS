import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/legendary_onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NEXT stays white with black copy on dark onboarding art', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegendaryOnboardingScreen(onFinish: () {}),
      ),
    );
    await tester.pump();

    final buttonFinder = find.widgetWithText(ElevatedButton, 'NEXT');
    expect(buttonFinder, findsOneWidget);
    final button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}), Colors.white);
    expect(button.style?.foregroundColor?.resolve(<WidgetState>{}), Colors.black);

    final label = tester.widget<Text>(find.text('NEXT'));
    expect(label.style?.color, Colors.black);
    expect(find.text('SKIP →'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
