import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MapPin listingPin({
    required String id,
    required String category,
    String? type,
  }) {
    return MapPin.listingAt(
      Listing(id: id, category: category, listingType: type),
      20.2,
      -87.4,
    );
  }

  final person = MapPin.profileAt(const Profile(id: 'person-1'), 20.2, -87.4);

  test('map pin identity remains stable across provider rebuilds', () {
    final first = listingPin(id: 'listing-1', category: 'property');
    final rebuilt = listingPin(id: 'listing-1', category: 'property');

    expect(first, rebuilt);
    expect({first, rebuilt}, hasLength(1));
  });

  test('map filters expose only categories backed by live map data', () {
    final property = listingPin(id: 'property-1', category: 'property');
    final worker = listingPin(id: 'worker-1', category: 'worker');
    final service = listingPin(
      id: 'service-1',
      category: 'other',
      type: 'service',
    );
    final yacht = listingPin(id: 'yacht-1', category: 'yacht');

    expect(mapPinMatchesCategory(property, 'properties'), isTrue);
    expect(mapPinMatchesCategory(worker, 'services'), isTrue);
    expect(mapPinMatchesCategory(service, 'services'), isTrue);
    expect(mapPinMatchesCategory(yacht, 'vehicles'), isTrue);
    expect(mapPinMatchesCategory(person, 'people'), isTrue);
    expect(mapPinMatchesCategory(person, 'properties'), isFalse);
    expect(mapPinMatchesCategory(property, 'events'), isFalse);
  });
}
