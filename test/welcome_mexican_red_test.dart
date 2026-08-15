import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_cta_button.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/ai_search_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/search_frame_shine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hero wordmark paints huge italic SWIPESS in Mexican red', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: SwipessLogo(
              width: 420,
              variant: SwipessLogoVariant.hero,
              color: AppTheme.mexicanRed,
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('SWIPESS'));
    expect(text.style?.fontSize, greaterThanOrEqualTo(72));
    expect(text.style?.fontStyle, FontStyle.italic);
    expect(text.style?.color, AppTheme.mexicanRed);
  });

  testWidgets('Mexican CTA uses the Rosa Mexicano gradient', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipessCtaButton(
            label: 'CREATE ACCOUNT',
            tone: SwipessCtaTone.mexican,
            onPressed: () {},
          ),
        ),
      ),
    );

    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = box.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors.first, AppTheme.mexicanRed);
    expect(gradient.colors.last, AppTheme.brandPrimary);
  });

  testWidgets('Mexican LOG IN CTA is the primary auth action tone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipessCtaButton(
            label: 'LOG IN',
            icon: Icons.auto_awesome_rounded,
            tone: SwipessCtaTone.mexican,
            onPressed: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<SwipessCtaButton>(
      find.byType(SwipessCtaButton),
    );
    expect(button.tone, SwipessCtaTone.mexican);
    expect(find.text('LOG IN'), findsOneWidget);
  });

  testWidgets('AI search bar hosts inner + frame shine painters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Padding(padding: EdgeInsets.all(16), child: AiSearchBar()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ask AI to find anything...'), findsOneWidget);
    expect(find.byType(SearchFrameShine), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
