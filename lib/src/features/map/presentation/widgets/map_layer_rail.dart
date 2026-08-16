import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Minimal, glassmorphic layer controls without glowing neon colors.
class MapLayerRail extends StatelessWidget {
  const MapLayerRail({
    super.key,
    required this.layer,
    required this.listingCount,
    required this.peopleCount,
    required this.onLayer,
  });

  final String layer;
  final int listingCount;
  final int peopleCount;
  final ValueChanged<String> onLayer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(120),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(60), width: 1.25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LayerOrb(
                icon: Icons.public_rounded,
                label: 'Show all map results',
                selected: layer == 'all',
                onTap: () => onLayer('all'),
              ),
              const SizedBox(height: 4),
              _LayerOrb(
                icon: Icons.apartment_rounded,
                label: 'Show listings, $listingCount results',
                selected: layer == 'listings',
                onTap: () => onLayer('listings'),
              ),
              const SizedBox(height: 4),
              _LayerOrb(
                icon: Icons.people_alt_rounded,
                label: 'Show people, $peopleCount results',
                selected: layer == 'people',
                onTap: () => onLayer('people'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerOrb extends StatelessWidget {
  const _LayerOrb({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? const Color(0xFFFF4D00)
                      : Colors.transparent,
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : Colors.white70,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral circular HUD control that stays readable on satellite imagery.
class MapHudCircle extends StatelessWidget {
  const MapHudCircle({
    super.key,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.accent = false,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool accent;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final control = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (selected || accent)
                  ? Colors.white
                  : const Color(0xFF0A0A0D),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
            ),
            child: Icon(
              icon,
              color: (selected || accent) ? Colors.black : Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );

    if (semanticLabel == null) return control;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Tooltip(message: semanticLabel!, child: control),
    );
  }
}
