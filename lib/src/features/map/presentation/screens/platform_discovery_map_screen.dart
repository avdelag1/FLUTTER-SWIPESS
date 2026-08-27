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
      iconTheme: base.iconTheme.copyWith(color: Colors.black),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll<Color>(Colors.black),
          overlayColor:
              const WidgetStatePropertyAll<Color>(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          overlayColor:
              const WidgetStatePropertyAll<Color>(Colors.transparent),
        ),
      ),
    );

    return Theme(
      data: mapTheme,
      child: IconTheme(
        data: const IconThemeData(color: Colors.black),
        child: buildPlatformDiscoveryMap(
          onClose: onClose,
          showCitiesOnOpen: showCitiesOnOpen,
        ),
      ),
    );
  }
}
