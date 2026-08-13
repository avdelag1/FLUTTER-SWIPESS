import 'package:flutter_swipes/src/features/map/data/map_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('10 km search radius frames a regional drone zoom', () {
    expect(MapCameraMath.zoomForRadiusKm(10), closeTo(9.08, 0.05));
    expect(MapCameraMath.zoomForRadiusKm(5), closeTo(10.08, 0.05));
    expect(MapCameraMath.openAltitudeZoom, lessThan(MapCameraMath.zoomForRadiusKm(10)));
  });
}
