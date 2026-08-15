import 'dart:math' as math;

/// Camera math for the map view.
abstract final class MapCameraMath {
  /// Regional frame for a search radius.
  static double zoomForRadiusKm(int km) {
    // Increased base zoom by 1.5 to provide a stronger zoom closer to the user
    final z = 15.5 - math.log(math.max(km, 1)) / math.ln2;
    return z.clamp(7.2, 18.0);
  }

  /// Initial zoom level when the map opens.
  static const openAltitudeZoom = 4.0;
  static const globeAltitudeZoom = 4.0;

  static const flyInDurationMs = 3000;

  static const openBankDegrees = 15.0; // slight bank on fly-in
  static const openPitch = 1.0; // steeper on dive
  static const cruisePitch = 0.698; // ~40 degrees
  static const perspective = 0.0015;
  static const stageScale = 1.6;
  static const stageTranslateY = -120.0;

  static const openGlideMs = 3000;

  static double clusterCellDegrees(double zoom) {
    final degPerPx = 360.0 / (256.0 * math.pow(2, zoom.clamp(3, 18)));
    return (degPerPx * 28).clamp(0.0028, 0.012);
  }

  static const alwaysShowBelow = 28;
}
