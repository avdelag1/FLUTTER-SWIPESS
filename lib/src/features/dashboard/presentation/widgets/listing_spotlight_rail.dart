import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Live listings in the selected city / radius — not demo Unsplash cards.
class ListingSpotlightRail extends ConsumerWidget {
  const ListingSpotlightRail({super.key, required this.isLight});

  final bool isLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final listings = (ref.watch(mapListingsProvider).value ?? const <Listing>[])
        .take(8)
        .toList();
    if (listings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Row(
            children: [
              Text(
                'IN YOUR RADIUS',
                style: AppTheme.displayItalic.copyWith(
                  fontSize: 16,
                  letterSpacing: 1.4,
                  color: ink,
                ),
              ),
              const Spacer(),
              Text(
                '${listings.length} LISTINGS',
                style: GoogleFonts.plusJakartaSans(
                  color: ink.withAlpha(140),
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        for (final listing in listings) ...[
          _SpotlightCard(listing: listing, isLight: isLight),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.listing, required this.isLight});

  final Listing listing;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final image = listing.primaryImage;
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ListingDetailScreen(listingData: listing),
          ),
        );
      },
      child: Container(
        height: 210,
        decoration: AppTheme.qfNeoFrame(isLight: isLight),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF16161C)),
              )
            else
              const ColoredBox(color: Color(0xFF16161C)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xE6000000)],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.formattedPrice,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    (listing.title ?? 'Listing').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFFEB4898),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.formattedLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
