import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/dashboard_dock.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';

void main() {
  final testListings = [
    Listing(
      id: '1',
      title: 'Luxury Villa',
      city: 'Miami',
      images: const [],
      price: 5000,
      description: 'Beautiful villa',
      category: 'property',
      amenities: const [],
    ),
    Listing(
      id: '2',
      title: 'Sports Car',
      city: 'Miami',
      images: const [],
      price: 200,
      description: 'Fast car',
      category: 'vehicle',
      amenities: const [],
    ),
  ];

  testWidgets('Swipe Reel renders card, action rail, and current chrome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swipeListingsProvider('property').overrideWith((ref) => testListings),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ClientSwipeContainer(
              categoryId: 'property',
              categoryTitle: 'Property',
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('AI'), findsWidgets);
    expect(find.byIcon(Icons.share_rounded), findsWidgets);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);
    expect(find.text('Luxury Villa'), findsWidgets);

    // Current swipe chrome reuses the same compact navigation dock as the
    // dashboard; the old dashboard_rounded icon is no longer part of it.
    expect(find.byType(DashboardDock), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsWidgets);
  });

  testWidgets('Swipe Reel exhausted state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swipeListingsProvider('property').overrideWith((ref) => []),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ClientSwipeContainer(
              categoryId: 'property',
              categoryTitle: 'Property',
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Move the slider to search further'), findsOneWidget);
  });
}
