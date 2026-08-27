import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen_v3.dart';

/// Backwards-compatible native map entry point.
///
/// Keep the V2 name because existing platform/bootstrap code imports it, while
/// the actual implementation lives in V3. This avoids stale UI logic from older
/// builds being reintroduced by another caller.
class RealMapboxScreenV2 extends RealMapboxScreenV3 {
  const RealMapboxScreenV2({
    super.key,
    super.onClose,
    super.showCitiesOnOpen,
    super.onMapReady,
  });
}
