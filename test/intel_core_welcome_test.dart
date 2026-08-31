import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/ai_disclosure.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_welcome_grid.dart';

void main() {
  testWidgets('AI welcome shows compact conversation suggestions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IntelWelcomeGrid(isLight: true, onPick: (_) {}),
            ),
          ),
        ),
      ),
    );

    expect(find.text('How can I help?'), findsOneWidget);
    expect(find.text('Ask anything, or start with one of these.'), findsOneWidget);
    expect(find.text('Find a place'), findsOneWidget);
    expect(find.text('Find a worker'), findsOneWidget);
    expect(find.text('People nearby'), findsOneWidget);
    expect(find.text('What’s happening?'), findsOneWidget);
    expect(find.text('Yachts'), findsOneWidget);
    expect(find.text('Motorcycles'), findsOneWidget);
  });

  testWidgets('AI suggestion sends its prompt directly to the conversation', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IntelWelcomeGrid(
                isLight: true,
                onPick: (prompt) => picked = prompt,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Find a place'));
    await tester.pump();
    expect(picked, 'Help me find a property that matches what I need');
  });

  testWidgets('AI disclosure names the live model and fallbacks', (
    tester,
  ) async {
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
    expect(
      find.textContaining('Google Gemini, Moonshot & MiniMax'),
      findsOneWidget,
    );
    expect(find.textContaining('password or payment'), findsOneWidget);
  });

  testWidgets('compact disclosure includes model and AI warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiDisclosure(isLight: false, showModelLine: true)),
      ),
    );

    expect(find.textContaining('AI ·'), findsOneWidget);
    expect(find.textContaining('Llama 3.3 (via Groq)'), findsOneWidget);
    expect(find.textContaining('Gemini & MiniMax fallbacks'), findsOneWidget);
  });
}
