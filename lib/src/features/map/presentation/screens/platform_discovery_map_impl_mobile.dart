import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v4.dart';

Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return _NativeDiscoveryMapBootstrap(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}

class _NativeDiscoveryMapBootstrap extends StatefulWidget {
  const _NativeDiscoveryMapBootstrap({
    required this.onClose,
    required this.showCitiesOnOpen,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  State<_NativeDiscoveryMapBootstrap> createState() =>
      _NativeDiscoveryMapBootstrapState();
}

class _NativeDiscoveryMapBootstrapState
    extends State<_NativeDiscoveryMapBootstrap> {
  late final Future<bool> _mapboxReady = MapboxRuntimeConfig.ensureConfigured();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _mapboxReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFF0A0A0D),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        if (snapshot.data == true) {
          return RealMapboxScreen(
            onClose: widget.onClose,
            showCitiesOnOpen: widget.showCitiesOnOpen,
          );
        }

        // A missing/misconfigured Mapbox token must never make the discovery map
        // unusable. The Flutter-rendered map uses the same listings, people,
        // radius, city chips, filters and navigation with public fallback tiles.
        return WebDiscoveryMapScreenV4(
          onClose: widget.onClose,
          showCitiesOnOpen: widget.showCitiesOnOpen,
        );
      },
    );
  }
}
