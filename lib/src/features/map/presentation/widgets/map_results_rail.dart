import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `PassportMapResultsRail` — nearby pins as a snap strip.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '${pins.length} IN YOUR RADIUS',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: pins.length.clamp(0, 24),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
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
                onTap: () => onSelect(pin),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 148,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.white24,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image != null)
                        Image.network(image, fit: BoxFit.cover)
                      else
                        ColoredBox(
                          color: pin.isListing
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF4F46E5),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pin.isListing
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pin.isListing ? 'LISTING' : 'PERSON',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            if (meta.isNotEmpty)
                              Text(
                                meta,
                                maxLines: 1,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.brandPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
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
