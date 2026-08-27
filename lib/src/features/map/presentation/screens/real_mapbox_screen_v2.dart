import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen_v3.dart';
import 'package:go_router/go_router.dart';

/// Backwards-compatible native map entry point.
///
/// V3 owns the actual native Mapbox experience. This wrapper deliberately adds
/// two release-safety affordances without forking the map again:
/// - a dedicated Back button, separate from the hamburger menu;
/// - a tiny Codemagic build fingerprint so TestFlight can prove which Git
///   commit/build is actually installed on the phone.
///
/// The fingerprint only appears when CI injects SWIPESS_BUILD_SHA, so local
/// development stays clean.
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

  void _closeMap(BuildContext context) {
    if (onClose != null) {
      onClose!();
    } else {
      context.go(AppPaths.clientDashboard);
    }
  }

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

        // Separate map exit control. The hamburger inside V3 remains a menu
        // toggle only; it must never double as Back/Close.
        Positioned(
          top: top,
          left: 43,
          child: Semantics(
            button: true,
            label: 'Back from map',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _closeMap(context),
              child: Container(
                width: 36,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 9,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: Color(0xFF111318),
                ),
              ),
            ),
          ),
        ),

        if (buildSha.isNotEmpty)
          Positioned(
            top: top + 82,
            right: 9,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xD9111317),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${buildChannel.isEmpty ? 'CI' : buildChannel}${buildNumber.isEmpty ? '' : ' #$buildNumber'} • $shortSha',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
