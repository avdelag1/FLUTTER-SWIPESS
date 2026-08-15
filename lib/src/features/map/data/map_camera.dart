import 'dart:math' as math;

/// Camera math for the map view.
abstract final class MapCameraMath {
  /// Regional frame for a search radius.
  static double zoomForRadiusKm(int km) {
    // Increased base zoom to zoom in much closer to the user!
    final z = 16.0 - math.log(math.max(km, 1)) / math.ln2;
    return z.clamp(9.0, 18.0);
  }

  /// Initial zoom level when the map opens (start high to see fly-in).
  static const openAltitudeZoom = 4.0;
  static const globeAltitudeZoom = 4.0;
  
  /// Fly-in duration needs to be long enough to see the zoom!
  static const flyInDurationMs = 3000;

  /// Airplane bank (tilt side-to-side)
  static const openBankDegrees = 12.0;

  /// Pitch in radians. Make this extremely steep for a true "fly" horizon view!
  static const openPitch = 1.25;
  static const cruisePitch = 1.05;

  /// Perspective factor. 
  static const perspective = 0.0008;

  /// Scale after perspective to prevent clipping black void. Increase since pitch is steep.
  static const stageScale = 2.1;
  static const stageTranslateY = -280.0;

  static const openGlideMs = 3000;

  static double clusterCellDegrees(double zoom) {
    final degPerPx = 360.0 / (256.0 * math.pow(2, zoom.clamp(3, 18)));
    return (degPerPx * 28).clamp(0.0028, 0.012);
  }

  static const alwaysShowBelow = 28;
}
