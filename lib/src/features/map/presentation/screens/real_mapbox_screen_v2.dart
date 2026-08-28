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
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    const buildSha = String.fromEnvironment('SWIPESS_BUILD_SHA');
    const buildNumber = String.fromEnvironment('SWIPESS_BUILD_NUMBER');
    const buildChannel = String.fromEnvironment('SWIPESS_BUILD_CHANNEL');
    final shortSha = buildSha.length >= 7 ? buildSha.substring(0, 7) : buildSha;
    final top = MediaQuery.paddingOf(context).top + 4;

    return Stack(
      fit: StackFit.expand,
      children: [
        RealMapboxScreenV3(
          onClose: onClose,
          showCitiesOnOpen: showCitiesOnOpen,
          onMapReady: onMapReady,
        ),
      ],
    );
  }
}
