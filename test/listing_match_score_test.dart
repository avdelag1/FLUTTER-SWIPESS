import 'package:flutter_swipes/src/features/swipes/domain/listing_match_score.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const listing = Listing(
    id: '1',
    title: 'Casa',
    category: 'property',
    listingType: 'rent',
    price: 1200,
    beds: 2,
    baths: 1,
    furnished: true,
    petFriendly: true,
    city: 'Tulum',
    propertyType: 'apartment',
  );

  test('hides match meter when no extra filters are set', () {
    expect(listingMatchPercentage(listing, SwipeFilter()), 0);
  });

  test('scores a listing inside the active price and city filters', () {
    final filters = SwipeFilter(
      minPrice: 800,
      maxPrice: 2000,
      city: 'Tulum',
      interestType: 'rent',
    );
    final score = listingMatchPercentage(listing, filters);
    expect(score, greaterThanOrEqualTo(55));
    expect(score, lessThanOrEqualTo(99));
  });

  test('still returns a floor score when filters miss', () {
    final filters = SwipeFilter(
      minPrice: 5000,
      maxPrice: 9000,
      city: 'Boston',
    );
    expect(listingMatchPercentage(listing, filters), 55);
  });
}
