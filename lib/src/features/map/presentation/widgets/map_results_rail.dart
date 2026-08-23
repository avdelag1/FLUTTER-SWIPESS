import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact listing/people strip. Sits above the GPS HUD, never on top of it.
class MapResultsRail extends StatelessWidget {
  const MapResultsRail({
    super.key,
    required this.pins,
    required this.selectedId,
    required this.onSelect,
  });

  final List<MapPin> pins;
  final String? selectedId;
  final ValueChanged<MapPin> onSelect;

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) return const SizedBox.shrink();
    final listings = pins.where((p) => p.isListing).length;
    final people = pins.length - listings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _CountChip(
                label: '${pins.length} IN YOUR RADIUS',
                colors: const [Color(0xFF9D4EDD), Color(0xFFFF4D00)],
              ),
              if (listings > 0)
                _CountChip(
                  label: '$listings LISTINGS',
                  colors: const [Color(0xFFFF4D00), Color(0xFF0072FF)],
                ),
              if (people > 0)
                _CountChip(
                  label: '$people ACTIVE',
                  colors: const [Color(0xFF10B981), Color(0xFFFF6B35)],
                  icon: Icons.bolt_rounded,
                ),
            ],
          ),
        ),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pins.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final pin = pins[i];
              final selected = pin.id == selectedId;
              final title = pin.isListing
                  ? (pin.listing?.title ?? 'Listing')
                  : (pin.profile?.displayName ?? 'User');
              final image = pin.isListing
                  ? pin.listing?.primaryImage
                  : pin.profile?.avatarUrl;
              final meta = pin.isListing
                  ? (pin.listing?.formattedPrice ?? '')
                  : (pin.profile?.city ?? '');
              return GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  onSelect(pin);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 148,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? Colors.white : const Color(0x55FF4D00),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D00)
                            .withAlpha(selected ? 80 : 30),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image != null && image.isNotEmpty)
                        Image.network(image, fit: BoxFit.cover)
                      else
                        const ColoredBox(color: Color(0xFF1E3A5F)),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xE60B1220)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            if (meta.isNotEmpty)
                              Text(
                                meta,
                                maxLines: 1,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFFF6B35),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.colors, this.icon});

  final String label;
  final List<Color> colors;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: colors),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
