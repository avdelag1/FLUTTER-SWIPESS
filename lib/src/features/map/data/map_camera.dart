import 'dart:math' as math;

/// Cap `zoomForRadiusKm` / cinematic open framing — raster fly-in.
abstract final class MapCameraMath {
  /// Regional frame for a search radius. 10 km → ~9.1.
  static double zoomForRadiusKm(int km) {
    final z = 12.4 - math.log(math.max(km, 1)) / math.ln2;
    return z.clamp(7.2, 13.2);
  }

  /// High drone altitude the open glide starts from.
  static const openAltitudeZoom = 5.4;

  /// Airplane bank on open, unwinds to north as we dive in.
  static const openBankDegrees = 22.0;

  static const openGlideMs = 1600;
}
