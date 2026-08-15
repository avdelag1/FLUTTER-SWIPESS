import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';

void main() {
  final testListings = [
    Listing(
      id: '1',
      title: 'Luxury Villa',
      city: 'Miami',
      images: ['https://example.com/1.jpg'],
      price: 5000,
      description: 'Beautiful villa',
      category: 'property',
      amenities: [],
    ),
    Listing(
      id: '2',
      title: 'Sports Car',
      city: 'Miami',
      images: ['https://example.com/2.jpg'],
      price: 200,
      description: 'Fast car',
      category: 'vehicle',
      amenities: [],
    ),
  ];

  testWidgets('Swipe Reel Parity: Renders card, side rail, and chrome', (WidgetTester tester) async {
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

    // Verify Action Rail exists
    expect(find.text('AI'), findsWidgets);
    expect(find.byIcon(Icons.share_rounded), findsWidgets);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);

    // Verify Card info exists
    expect(find.text('Luxury Villa'), findsWidgets);

    // Verify DashboardDock exists (chrome)
    expect(find.byIcon(Icons.dashboard_rounded), findsWidgets);
  });

  testWidgets('Swipe Reel Parity: Exhausted state', (WidgetTester tester) async {
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

    // Verify exhausted text
    expect(find.text('Move the slider to search further'), findsOneWidget);
  });
}
