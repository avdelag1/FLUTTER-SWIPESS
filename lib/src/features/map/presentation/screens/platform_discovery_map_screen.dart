import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/platform_discovery_map_impl_mobile.dart'
    if (dart.library.html) 'package:flutter_swipes/src/features/map/presentation/screens/platform_discovery_map_impl_web.dart';

/// One public map entry point with a renderer chosen at compile time.
///
/// Web compiles only the Flutter-rendered map. Native compiles only the
/// Mapbox SDK map. This prevents unsupported web Mapbox APIs from entering
/// the browser build or stealing pointer events from Flutter controls.
class PlatformDiscoveryMapScreen extends StatelessWidget {
  const PlatformDiscoveryMapScreen({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    // Map controls intentionally use a local interaction theme. Some controls
    // (notably TextButton/IconButton inside decorated map panels) can otherwise
    // paint their web hover ink on the nearest full-screen Material ancestor,
    // which looks like a grey layer flashing over the entire map. Keeping the
    // overlay transparent here removes that artifact without changing the rest
    // of the app. The black icon fallback also makes every light map control
    // readable even when a child does not specify its own icon color.
    final mapTheme = base.copyWith(
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      iconTheme: base.iconTheme.copyWith(
        color: const Color(0xFF111318),
        size: 18,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll<Color>(
            Color(0xFF111318),
          ),
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll<Color>(
            Color(0xFF111318),
          ),
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        ),
      ),
    );

    return Theme(
      data: mapTheme,
      child: IconTheme(
        data: const IconThemeData(color: Color(0xFF111318), size: 18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF06182B)),
            buildPlatformDiscoveryMap(
              onClose: onClose,
              showCitiesOnOpen: showCitiesOnOpen,
            ),

            // The top filter rail and optional city rail scroll horizontally.
            // Give their far-right end a soft optical fade so pills disappear
            // naturally into the screen edge instead of looking sliced by a
            // rectangular phone/browser boundary. This is a transparent shade,
            // not a frame, so there is no visible vertical seam.
            const Positioned(
              top: 48,
              right: 0,
              width: 30,
              height: 90,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0x16FFFFFF),
                        Color(0x6BFFFFFF),
                      ],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
