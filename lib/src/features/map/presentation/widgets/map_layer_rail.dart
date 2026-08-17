import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Compact liquid-glass layer controls with restrained active treatment.
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
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(52), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(54),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
              _LayerOrb(
                icon: Icons.apartment_rounded,
                label: 'Show listings, $listingCount results',
                selected: layer == 'listings',
                onTap: () => onLayer('listings'),
              ),
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
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Colors.white.withAlpha(26)
                      : Colors.transparent,
                  border: selected
                      ? Border.all(color: Colors.white.withAlpha(52), width: 0.7)
                      : null,
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? const Color(0xFFFF6B35)
                      : Colors.white.withAlpha(190),
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral liquid-glass HUD control that stays readable on satellite imagery.
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
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (selected || accent)
                      ? Colors.white.withAlpha(220)
                      : Colors.black.withAlpha(92),
                  border: Border.all(
                    color: (selected || accent)
                        ? Colors.white.withAlpha(230)
                        : Colors.white.withAlpha(62),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(58),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: (selected || accent)
                      ? const Color(0xFF111318)
                      : Colors.white.withAlpha(238),
                  size: 18,
                ),
              ),
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
