import 'package:flutter_swipes/src/core/constants/listing_locations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonicalizes AI-friendly city labels', () {
    expect(ListingLocations.canonicalName('tulum, mexico'), 'Tulum');
    expect(ListingLocations.canonicalName('Cancún, Quintana Roo'), 'Cancún');
    expect(ListingLocations.resolve('TULUM, MEXICO')?.lat, 20.2111);
  });

  test('does not silently invent coordinates for unsupported cities', () {
    expect(ListingLocations.canonicalName('Imaginary City'), isNull);
    expect(ListingLocations.resolve('Imaginary City'), isNull);
  });
}
