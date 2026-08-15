import 'dart:math' as math;

/// Camera math for the map view.
abstract final class MapCameraMath {
  /// Regional frame for a search radius.
  static double zoomForRadiusKm(int km) {
    final z = 14.0 - math.log(math.max(km, 1)) / math.ln2;
    return z.clamp(7.2, 15.0);
  }

  /// Initial zoom level when the map opens (start high to see fly-in).
  static const openAltitudeZoom = 4.0;
  static const globeAltitudeZoom = 4.0;
  
  /// Fly-in duration needs to be long enough to see the zoom!
  static const flyInDurationMs = 2400;

  /// Airplane bank (tilt side-to-side)
  static const openBankDegrees = 12.0;

  /// Pitch in radians.
  /// Used in MapPerspectiveStage.
  static const openPitch = 0.85;
  static const cruisePitch = 0.65;

  /// Perspective factor.
  static const perspective = 0.001;

  /// Scale after perspective to prevent clipping black void.
  static const stageScale = 1.35;

  static const openGlideMs = 2400;

  static double clusterCellDegrees(double zoom) {
    final degPerPx = 360.0 / (256.0 * math.pow(2, zoom.clamp(3, 18)));
    return (degPerPx * 28).clamp(0.0028, 0.012);
  }

  static const alwaysShowBelow = 28;
}
