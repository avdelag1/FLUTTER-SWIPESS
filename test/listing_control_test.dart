import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/my_listings_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/owner_properties_screen.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';

void main() {
  Future<void> pumpListingControl(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myListingsProvider.overrideWith(
            (ref, status) async => const <Listing>[],
          ),
          ownerListingsStatsProvider.overrideWith(
            (ref) async => const OwnerListingsStats(
              total: 0,
              active: 0,
              views: 0,
              avgPrice: 0,
              categories: 0,
            ),
          ),
        ],
        child: const MaterialApp(home: OwnerPropertiesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('Listing Control chrome matches Cap asset terminal', (tester) async {
    await pumpListingControl(tester);

    expect(find.text('LISTING CONTROL'), findsOneWidget);
    expect(find.text('REAL-TIME ASSET MANAGEMENT PROTOCOL'), findsOneWidget);
    expect(find.text('ADD LISTING'), findsOneWidget);
    expect(find.text('GALLERY EMPTY'), findsOneWidget);
    expect(find.text('SEARCH ASSETS...'), findsOneWidget);
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('PROPERTIES'), findsOneWidget);
    expect(find.text('MOTORCYCLES'), findsOneWidget);
    expect(find.byKey(const Key('listing-control-spark')), findsOneWidget);
    expect(find.byType(CapBackButton), findsOneWidget);
  });

  testWidgets('spark opens the create-listing multi-option sheet', (tester) async {
    await pumpListingControl(tester);

    await tester.tap(find.byKey(const Key('listing-control-spark')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CREATE NEW LISTING'), findsOneWidget);
  });
}
