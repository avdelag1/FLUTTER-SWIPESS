import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/data/map_basemap.dart';
import 'package:flutter_swipes/src/features/map/data/map_camera.dart';
import 'package:flutter_swipes/src/features/map/data/map_cluster.dart';
import 'package:flutter_swipes/src/features/map/data/map_demo_pins.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_bottom_dock.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_pin_markers.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_preview_card.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('10 km search radius frames a regional drone zoom', () {
    expect(MapCameraMath.zoomForRadiusKm(10), closeTo(9.08, 0.05));
    expect(MapCameraMath.zoomForRadiusKm(5), closeTo(10.08, 0.05));
    expect(
      MapCameraMath.openAltitudeZoom,
      lessThan(MapCameraMath.zoomForRadiusKm(10)),
    );
  });

  test('cinematic pitch stays 3D after the fly-in', () {
    expect(MapCameraMath.openPitch, greaterThan(MapCameraMath.cruisePitch));
    expect(MapCameraMath.cruisePitch, greaterThan(0.4));
    expect(MapCameraMath.perspective, greaterThan(0));
  });

  test('basemap is colorful voyager, not the black street filter', () {
    expect(MapBasemap.streetsUrl.contains('voyager'), isTrue);
    expect(MapBasemap.streetsUrl.contains('dark_all'), isFalse);
  });

  test('a single live listing is padded so the map is not empty', () {
    final center = const LatLng(20.2114, -87.4654);
    final live = [
      Listing(
        id: 'live-1',
        title: 'Tranquil Oasis',
        latitude: 20.21,
        longitude: -87.46,
      ),
    ];
    final merged = listingsForMap(live, center, 'Tulum');
    expect(merged.length, greaterThanOrEqualTo(5));
  });

  test('five nearby listings stay unclustered at a 50 km zoom', () {
    final center = const LatLng(20.2114, -87.4654);
    final listings = demoMapListings(center, 'Tulum');
    expect(listings.length, greaterThanOrEqualTo(5));
    final pins = listings.map(MapPin.listing).toList();
    final groups = clusterMapPins(pins, MapCameraMath.zoomForRadiusKm(50));
    expect(groups.length, listings.length);
    expect(groups.every((g) => g.count == 1), isTrue);
  });

  test('cluster cells stay under a kilometer-scale merge', () {
    expect(MapCameraMath.clusterCellDegrees(7.2), lessThan(0.02));
    expect(MapCameraMath.clusterCellDegrees(12), lessThan(0.01));
  });

  testWidgets('listing pin keeps the photo and title in one marker',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapListingPinMarker(
              title: 'Tranquil Oasis',
              selected: false,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Tranquil Oasis'), findsOneWidget);
    expect(find.byType(MapListingPinMarker), findsOneWidget);
  });

  testWidgets('preview sits above the GPS HUD, not on top of it',
      (tester) async {
    final listing = Listing(
      id: 'p1',
      title: 'Tranquil Oasis',
      neighborhood: 'Beleta',
      city: 'Tulum',
      price: 10000,
      currency: 'USD',
      latitude: 20.21,
      longitude: -87.46,
      images: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MapBottomDock(
              preview: MapPreviewCard(
                pin: MapPin.listing(listing),
                onOpen: () {},
                onClose: () {},
              ),
              rail: const SizedBox(key: ValueKey('rail-unused')),
              hud: const SizedBox(
                key: ValueKey('map-hud-probe'),
                height: 44,
                child: Text('You are here'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('TRANQUIL OASIS'), findsOneWidget);
    expect(find.text('You are here'), findsOneWidget);
    final previewBottom =
        tester.getBottomLeft(find.byType(MapPreviewCard)).dy;
    final hudTop = tester.getTopLeft(find.byKey(const ValueKey('map-hud-slot'))).dy;
    expect(hudTop, greaterThanOrEqualTo(previewBottom - 0.5));
    expect(find.byKey(const ValueKey('map-rail-slot')), findsNothing);
  });
}
