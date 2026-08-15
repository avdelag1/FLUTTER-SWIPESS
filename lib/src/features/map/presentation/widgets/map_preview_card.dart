import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact selected-pin sheet. Height stays small so the GPS / radius HUD
/// can sit under it without being covered.
class MapPreviewCard extends StatelessWidget {
  const MapPreviewCard({
    super.key,
    required this.pin,
    required this.onOpen,
    required this.onClose,
  });

  final MapPin pin;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    final title = pin.isListing
        ? (pin.listing?.title ?? 'Listing')
        : pin.profile?.displayName ?? 'User';
    final subtitle = pin.isListing
        ? (pin.listing?.formattedLocation ?? '')
        : (pin.profile?.city ?? '');
    final price = pin.isListing
        ? (pin.listing?.formattedPrice ?? '')
        : (pin.profile?.role ?? '');
    final imageUrl = pin.isListing
        ? pin.listing?.primaryImage
        : pin.profile?.avatarUrl;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xF2141824),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x88FF4D00)),
          boxShadow: const [
            BoxShadow(color: Color(0x66FF4D00), blurRadius: 16),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: height,
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : const ColoredBox(color: Color(0xFF1E3A5F)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (price.isNotEmpty)
                          Text(
                            price,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.brandPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onOpen,
                          child: Text(
                            pin.isListing ? 'DETAILS →' : 'PROFILE →',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFFF6B35),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
