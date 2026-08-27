import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen_v2.dart';
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
  Timer? _mapLoadWatchdog;
  bool _watchdogArmed = false;
  bool _nativeMapReportedReady = false;
  bool _useFallback = false;

  void _armWatchdog() {
    if (_watchdogArmed || _nativeMapReportedReady || _useFallback) return;
    _watchdogArmed = true;
    _mapLoadWatchdog = Timer(const Duration(seconds: 8), () {
      if (!mounted || _nativeMapReportedReady) return;
      setState(() => _useFallback = true);
    });
  }

  void _markNativeMapReady() {
    _nativeMapReportedReady = true;
    _mapLoadWatchdog?.cancel();
  }

  @override
  void dispose() {
    _mapLoadWatchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _mapboxReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFFF1F4F7),
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

        if (snapshot.data == true && !_useFallback) {
          _armWatchdog();
          return RealMapboxScreenV2(
            onClose: widget.onClose,
            showCitiesOnOpen: widget.showCitiesOnOpen,
            onMapReady: _markNativeMapReady,
          );
        }

        // Missing token, failed style load, or a native platform-view startup
        // problem must never leave a user staring at controls over a blank map.
        // Fall back to the Flutter-rendered map with the same live data.
        return WebDiscoveryMapScreenV4(
          onClose: widget.onClose,
          showCitiesOnOpen: widget.showCitiesOnOpen,
        );
      },
    );
  }
}
