import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';

Listing _sample() => const Listing(
  id: 'test-listing',
  title: 'Test listing',
  description: 'Test description for the listing detail screen.',
  category: 'property',
  listingType: 'rent',
  propertyType: 'house',
  price: 2500,
  currency: 'USD',
  city: 'Test City',
  neighborhood: 'Test Neighborhood',
  bedrooms: 2,
  beds: 2,
  bathrooms: 2,
  baths: 2,
  amenities: ['Wi-Fi', 'Kitchen'],
  images: [],
);

void main() {
  Future<void> pumpListing(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: ListingDetailScreen(listingData: _sample())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('listing page shows scroll body under the gallery', (
    tester,
  ) async {
    await pumpListing(tester);

    expect(find.textContaining('TEST LISTING'), findsOneWidget);
    expect(find.text('ABOUT THIS LISTING'), findsOneWidget);
    expect(find.text('HIGHLIGHTS'), findsOneWidget);
    expect(find.text('NEIGHBORHOOD'), findsOneWidget);
    expect(find.text('MATCH PROTOCOL'), findsOneWidget);
    expect(find.text('MESSAGE'), findsOneWidget);
    expect(find.byKey(const Key('listing-detail-header')), findsOneWidget);
    expect(find.byKey(const Key('listing-detail-nav')), findsOneWidget);
  });

  testWidgets('header and nav hide after scrolling down', (tester) async {
    await pumpListing(tester);

    IgnorePointer headerIgnore() {
      return tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byKey(const Key('listing-detail-header')),
          matching: find.byType(IgnorePointer),
        ),
      );
    }

    IgnorePointer navIgnore() {
      return tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byKey(const Key('listing-detail-nav')),
          matching: find.byType(IgnorePointer),
        ),
      );
    }

    expect(headerIgnore().ignoring, isFalse);
    expect(navIgnore().ignoring, isFalse);

    await tester.fling(
      find.byKey(const Key('listing-detail-scroll')),
      const Offset(0, -480),
      2400,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(headerIgnore().ignoring, isTrue);
    expect(navIgnore().ignoring, isTrue);
  });
}
