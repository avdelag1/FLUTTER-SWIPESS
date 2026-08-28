import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/platform_discovery_map_screen.dart';
import 'package:go_router/go_router.dart';

/// Compatibility entry point for the discovery map.
///
/// Every map entry resolves through the same platform-aware renderer: Flutter
/// rendering on web for reliable input/markers and Mapbox Maps SDK on native.
/// On native, deep links and legacy callers open the passport-map overlay so
/// camera, pins, and filters stay warm instead of spawning a second map stack.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({
    super.key,
    this.asOverlay = false,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  /// Retained for backwards compatibility with existing callers.
  final bool asOverlay;
  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNativeOverlay());
    }
  }

  void _openNativeOverlay() {
    if (!mounted) return;
    ref
        .read(overlayModalsProvider.notifier)
        .openPassportMap(showCities: widget.showCitiesOnOpen);

    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.go(AppPaths.clientDashboard);
  }

  VoidCallback _defaultClose(BuildContext context) => () {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(AppPaths.clientDashboard);
    }
  };

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Native routes bounce through the overlay opener above and only flash
      // this dark canvas for a single frame.
      return const ColoredBox(color: Color(0xFF06182B));
    }

    return PlatformDiscoveryMapScreen(
      showCitiesOnOpen: widget.showCitiesOnOpen,
      onClose: widget.onClose ?? _defaultClose(context),
    );
  }
}
