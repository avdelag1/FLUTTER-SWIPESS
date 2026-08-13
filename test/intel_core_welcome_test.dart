import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/ai_disclosure.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_welcome_grid.dart';

void main() {
  testWidgets('Intel Core welcome shows category pills', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntelWelcomeGrid(
              isLight: true,
              onPick: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('INTEL CORE'), findsOneWidget);
    expect(find.text('CHOOSE A CATEGORY'), findsOneWidget);
    expect(find.text('PROPERTIES'), findsOneWidget);
    expect(find.text('WORKERS'), findsOneWidget);
    expect(find.text('MOTORCYCLES'), findsOneWidget);
    expect(find.text('BICYCLES'), findsOneWidget);
    expect(find.text('YACHTS'), findsOneWidget);
    expect(find.text('BUYERS'), findsOneWidget);
    expect(find.text('RENTERS'), findsOneWidget);
    expect(find.text('SEEKERS'), findsOneWidget);
  });

  testWidgets('Intel Core category opens prompt chips', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntelWelcomeGrid(
              isLight: true,
              onPick: (prompt) => picked = prompt,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('PROPERTIES'));
    await tester.pump();

    expect(find.text('PICK A PROMPT'), findsOneWidget);
    expect(find.text('All Rentals'), findsOneWidget);

    await tester.tap(find.text('All Rentals'));
    await tester.pump();
    expect(picked, 'Show me all rental properties');
  });

  testWidgets('AI disclosure names the live model and fallbacks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(12),
            child: AiDisclosure(
              isLight: true,
              variant: AiDisclosureVariant.roomy,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Llama 3.3 (via Groq)'), findsOneWidget);
    expect(find.textContaining('Google Gemini, Moonshot & MiniMax'), findsOneWidget);
    expect(find.textContaining('password or payment'), findsOneWidget);
  });

  testWidgets('compact disclosure includes AI can make mistakes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiDisclosure(isLight: false, showModelLine: true),
        ),
      ),
    );

    expect(find.textContaining('AI can make mistakes'), findsOneWidget);
    expect(find.textContaining('Using Llama 3.3 (via Groq)'), findsOneWidget);
  });
}
