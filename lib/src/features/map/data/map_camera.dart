import 'dart:math' as math;

/// Cap `zoomForRadiusKm` / cinematic open framing — raster fly-in + 3D pitch.
abstract final class MapCameraMath {
  /// Regional frame for a search radius. 10 km → ~9.1.
  static double zoomForRadiusKm(int km) {
    final z = 12.4 - math.log(math.max(km, 1)) / math.ln2;
    return z.clamp(7.2, 13.2);
  }

  /// High drone altitude the open glide starts from.
  static const openAltitudeZoom = 4.8;

  /// Airplane bank on open, unwinds as we dive in (widget tilt, not tiles).
  static const openBankDegrees = 18.0;

  /// Steep dive pitch at altitude (radians, ~48°).
  static const openPitch = 0.84;

  /// Cruise pitch after the fly-in so the map stays 3D (~32°).
  static const cruisePitch = 0.56;

  /// Perspective strength for the Matrix4 flying view.
  static const perspective = 0.00118;

  /// Scale after perspective so the tilted trapezoid still fills the screen.
  static const stageScale = 1.16;

  static const openGlideMs = 2000;

  /// Merge pins only when they would sit on top of each other (~450 m).
  /// Never use city-scale cells — that collapsed every Tulum listing into one.
  static double clusterCellDegrees(double zoom) {
    final degPerPx = 360.0 / (256.0 * math.pow(2, zoom.clamp(3, 18)));
    return (degPerPx * 28).clamp(0.0028, 0.012);
  }

  /// Keep every pin visible unless the map is actually crowded.
  static const alwaysShowBelow = 28;
}
