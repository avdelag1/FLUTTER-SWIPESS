import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// High-contrast layer controls without neon bloom around their frames.
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
          colors: const [Color(0xFFFF4D00), Color(0xFFE4007C)],
          badge: total,
          selected: layer == 'all',
          onTap: () => onLayer('all'),
        ),
        const SizedBox(height: 10),
        _LayerOrb(
          icon: Icons.apartment_rounded,
          colors: const [Color(0xFFFF6B35), Color(0xFFFF4D00)],
          badge: listingCount,
          selected: layer == 'listings',
          onTap: () => onLayer('listings'),
        ),
        const SizedBox(height: 10),
        _LayerOrb(
          icon: Icons.people_alt_rounded,
          colors: const [Color(0xFFEC4899), Color(0xFFE4007C)],
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
        AppHaptics.selection();
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
              color: selected ? colors.first : const Color(0xEFFFFFFF),
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 8),
              ],
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF111318),
              size: 21,
            ),
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

/// Neutral circular HUD control that stays readable on satellite imagery.
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
          color: (selected || accent) ? Colors.white : const Color(0xFF0A0A0D),
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, color: (selected || accent) ? Colors.black : Colors.white, size: 18),
      ),
    );
  }
}
