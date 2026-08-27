import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/mapbox_world_intro_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';

Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return _WebDiscoveryMapBootstrap(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}

class _WebDiscoveryMapBootstrap extends StatefulWidget {
  const _WebDiscoveryMapBootstrap({
    required this.onClose,
    required this.showCitiesOnOpen,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  State<_WebDiscoveryMapBootstrap> createState() =>
      _WebDiscoveryMapBootstrapState();
}

class _WebDiscoveryMapBootstrapState extends State<_WebDiscoveryMapBootstrap> {
  late final Future<bool> _mapboxReady = MapboxRuntimeConfig.ensureConfigured();
  Timer? _introWatchdog;
  bool _introWatchdogArmed = false;
  bool _introComplete = false;

  void _armIntroWatchdog() {
    if (_introWatchdogArmed || _introComplete) return;
    _introWatchdogArmed = true;
    _introWatchdog = Timer(const Duration(seconds: 7), _finishIntro);
  }

  void _finishIntro() {
    if (!mounted || _introComplete) return;
    _introWatchdog?.cancel();
    setState(() => _introComplete = true);
  }

  @override
  void dispose() {
    _introWatchdog?.cancel();
    super.dispose();
  }

  Widget _transition(Widget child, String key) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _mapboxReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFFF5F8FA),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black87,
                ),
              ),
            ),
          );
        }

        if (snapshot.data == true && !_introComplete) {
          _armIntroWatchdog();
          return _transition(
            MapboxWorldIntroScreen(onComplete: _finishIntro),
            'mapbox-world-intro',
          );
        }

        // The premium browser discovery screen remains the destination after
        // the actual Mapbox globe flight. If Mapbox initialization ever fails,
        // this also prevents a blank browser surface.
        return _transition(
          WebDiscoveryMapScreenV5(
            onClose: widget.onClose,
            showCitiesOnOpen: widget.showCitiesOnOpen,
          ),
          'web-discovery-map',
        );
      },
    );
  }
}
