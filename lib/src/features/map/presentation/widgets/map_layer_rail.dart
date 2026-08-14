import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap right-side layer buttons with colorful fills + count badges.
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
    final total = listingCount + peopleCount;
    return Column(
      children: [
        _LayerOrb(
          icon: Icons.public_rounded,
          colors: const [Color(0xFF9D4EDD), Color(0xFF00E5FF)],
          badge: total,
          selected: layer == 'all',
          onTap: () => onLayer('all'),
        ),
        const SizedBox(height: 10),
        _LayerOrb(
          icon: Icons.apartment_rounded,
          colors: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
          badge: listingCount,
          selected: layer == 'listings',
          onTap: () => onLayer('listings'),
        ),
        const SizedBox(height: 10),
        _LayerOrb(
          icon: Icons.people_alt_rounded,
          colors: const [Color(0xFF3B82F6), Color(0xFF9D4EDD)],
          badge: peopleCount,
          selected: layer == 'people',
          onTap: () => onLayer('people'),
        ),
      ],
    );
  }
}

class _LayerOrb extends StatelessWidget {
  const _LayerOrb({
    required this.icon,
    required this.colors,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> colors;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? colors
                    : [
                        const Color(0xF2161B27),
                        const Color(0xF210141C),
                      ],
              ),
              border: Border.all(
                color: selected ? Colors.white : colors.first,
                width: selected ? 2 : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withAlpha(selected ? 140 : 70),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.first,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text(
                  '$badge',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular HUD control with a colored ring so it stays readable on satellite.
class MapHudCircle extends StatelessWidget {
  const MapHudCircle({
    super.key,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: accent
              ? const LinearGradient(
                  colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
                )
              : null,
          color: accent ? null : const Color(0xF2161B27),
          border: Border.all(
            color: selected || accent
                ? const Color(0xFF00E5FF)
                : const Color(0xCCFFFFFF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (accent ? const Color(0xFF00C6FF) : Colors.black)
                  .withAlpha(100),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
