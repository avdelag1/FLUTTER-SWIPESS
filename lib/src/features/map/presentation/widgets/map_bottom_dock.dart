import 'package:flutter/material.dart';

/// Bottom stack: preview or rail first, GPS / you-are-here always underneath.
class MapBottomDock extends StatelessWidget {
  const MapBottomDock({
    super.key,
    required this.preview,
    required this.rail,
    required this.hud,
  });

  final Widget? preview;
  final Widget rail;
  final Widget hud;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview != null) ...[
          KeyedSubtree(
            key: const ValueKey('map-preview-slot'),
            child: preview!,
          ),
          const SizedBox(height: 10),
        ] else ...[
          KeyedSubtree(key: const ValueKey('map-rail-slot'), child: rail),
          const SizedBox(height: 10),
        ],
        KeyedSubtree(key: const ValueKey('map-hud-slot'), child: hud),
      ],
    );
  }
}

/// GPS + radius + you-are-here row. Always the last child of [MapBottomDock].
class MapGpsHud extends StatelessWidget {
  const MapGpsHud({
    super.key,
    required this.youAreHere,
    required this.locateButton,
    required this.radiusChip,
  });

  final Widget youAreHere;
  final Widget locateButton;
  final Widget radiusChip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        locateButton,
        const SizedBox(width: 8),
        Flexible(child: radiusChip),
        const SizedBox(width: 8),
        youAreHere,
      ],
    );
  }
}
