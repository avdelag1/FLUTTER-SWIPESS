import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/ai_disclosure.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_welcome_grid.dart';

void main() {
  testWidgets('AI welcome shows localized Tulum conversation suggestions', (
    tester,
  ) async {
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
    expect(
      find.text('Ask anything, or start with one of these.'),
      findsOneWidget,
    );
    expect(find.text('Find a cenote 🌴'), findsOneWidget);
    expect(find.text('Jungle party 🪩'), findsOneWidget);
    expect(find.text('Spiritual guide ✨'), findsOneWidget);
    expect(find.text('Tulum real estate 🏡'), findsOneWidget);
    expect(find.text('Scooter rental 🛵'), findsOneWidget);
    expect(find.text('Beach clubs 🏖️'), findsOneWidget);
  });

  testWidgets('localized AI suggestion sends its prompt directly', (
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

    await tester.tap(find.text('Find a cenote 🌴'));
    await tester.pump();
    expect(picked, 'Help me find the best secret cenotes in Tulum');
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

    expect(find.textContaining('GPT-OSS 120B (via Groq)'), findsOneWidget);
    expect(
      find.textContaining('Google Gemini, Moonshot Kimi & MiniMax'),
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
    expect(find.textContaining('GPT-OSS 120B (via Groq)'), findsOneWidget);
    expect(
      find.textContaining('Gemini, Kimi & MiniMax fallbacks'),
      findsOneWidget,
    );
  });
}
