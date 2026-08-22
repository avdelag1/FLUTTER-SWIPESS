import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_card_theme_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/holographic_id_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HolographicIDCard paints the static PEARL Local ID preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HolographicIDCard(
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

    expect(find.text('SWIPESS LOCAL ID'), findsOneWidget);
    expect(find.text('MAYA CRUZ'), findsOneWidget);
    expect(find.text('RESIDENT ID'), findsNothing);
    expect(find.text('SWIPESS GLOBAL REGISTRY'), findsNothing);
    expect(find.text('TAP TO OPEN FULL VAP ID + DOCUMENTS'), findsOneWidget);

    // The old profile card continuously shimmered and kept scheduling frames.
    // The canonical preview is intentionally static.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('vapCardThemeProvider follows the persisted theme index', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'vap-card-theme-index': 4});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(vapCardThemeIndexProvider.future);
    expect(container.read(vapCardThemeProvider).name, 'Nexus');

    await container.read(vapCardThemeIndexProvider.notifier).cycle();
    expect(container.read(vapCardThemeProvider).name, 'Pearl');
  });
}
