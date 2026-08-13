import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_card_theme_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/holographic_id_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HolographicIDCard paints the selected PEARL theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HolographicIDCard(
            theme: VapCardTheme.themes[2], // Rosa Mexicano
            name: 'Maya Cruz',
            idNumber: 'NX-ABCD1234',
            occupation: 'Architect',
            location: 'Tulum',
            years: '3',
            bio: 'Building in the jungle.',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('RESIDENT ID'), findsOneWidget);
    expect(find.text('MAYA CRUZ'), findsOneWidget);
    expect(find.text('SWIPESS GLOBAL REGISTRY'), findsOneWidget);

    final card = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HolographicIDCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
    final colors = (decoration.gradient! as LinearGradient).colors;
    expect(colors, VapCardTheme.themes[2].gradient);
  });

  testWidgets('vapCardThemeProvider follows the persisted theme index',
      (tester) async {
    SharedPreferences.setMockInitialValues({'vap-card-theme-index': 4});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(vapCardThemeIndexProvider.future);
    expect(container.read(vapCardThemeProvider).name, 'Nexus');

    await container.read(vapCardThemeIndexProvider.notifier).cycle();
    expect(container.read(vapCardThemeProvider).name, 'Pearl');
  });
}
