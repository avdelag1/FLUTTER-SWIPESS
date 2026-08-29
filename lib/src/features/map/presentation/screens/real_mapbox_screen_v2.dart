import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen_v3.dart';

/// Backwards-compatible native map entry point.
///
/// V3 owns every interactive map control, including Back and the hamburger
/// menu. This wrapper must stay pointer-transparent so it can never intercept a
/// V3 control again. Its only responsibility is the optional CI build
/// fingerprint used to prove which TestFlight build is installed.
class RealMapboxScreenV2 extends StatelessWidget {
  const RealMapboxScreenV2({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
    this.onMapReady,
    this.playIntro = false,
    this.onIntroComplete,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;
  final VoidCallback? onMapReady;
  final bool playIntro;
  final VoidCallback? onIntroComplete;

  @override
  Widget build(BuildContext context) {
    return RealMapboxScreenV3(
      onClose: onClose,
      showCitiesOnOpen: showCitiesOnOpen,
      onMapReady: onMapReady,
      playIntro: playIntro,
      onIntroComplete: onIntroComplete,
    );
  }
}
