import 'dart:math' as math;

/// Camera math for the map view.
abstract final class MapCameraMath {
  /// Regional frame for a search radius. 5 km → ~12.5.
  static double zoomForRadiusKm(int km) {
    final z = 14.0 - math.log(math.max(km, 1)) / math.ln2;
    return z.clamp(7.2, 15.0);
  }

  /// Initial zoom level when the map opens.
  static const openAltitudeZoom = 9.0;
  static const globeAltitudeZoom = 9.0;
  static const flyInDurationMs = 1200;

  /// Slight angle for presentation
  static const openBankDegrees = 5.0;

  /// Pitch in radians. 0.35 is about 20 degrees. Safe and doesn't flip.
  static const openPitch = 0.5;

  /// Normal pitch when settled.
  static const cruisePitch = 0.35;

  /// Perspective factor.
  static const perspective = 0.0008;

  /// Scale after perspective.
  static const stageScale = 1.15;

  static const openGlideMs = 1200;

  static double clusterCellDegrees(double zoom) {
    final degPerPx = 360.0 / (256.0 * math.pow(2, zoom.clamp(3, 18)));
    return (degPerPx * 28).clamp(0.0028, 0.012);
  }

  static const alwaysShowBelow = 28;
}
