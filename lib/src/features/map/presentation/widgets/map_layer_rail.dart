import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

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
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(52), width: .8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LayerChoice(
                icon: Icons.public_rounded,
                label: 'ALL',
                selected: layer == 'all',
                onTap: () => onLayer('all'),
              ),
              _LayerChoice(
                icon: Icons.apartment_rounded,
                label: 'LISTINGS',
                count: listingCount,
                selected: layer == 'listings',
                onTap: () => onLayer('listings'),
              ),
              _LayerChoice(
                icon: Icons.people_alt_rounded,
                label: 'USERS',
                count: peopleCount,
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

class _LayerChoice extends StatelessWidget {
  const _LayerChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count results',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withAlpha(36) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? Border.all(color: Colors.white.withAlpha(52), width: .7)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFFFF6B35)
                    : Colors.white.withAlpha(220),
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .55,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
                    width: .9,
                  ),
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
