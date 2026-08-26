import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Cap `ChatListingCard` / `ChatProfileCard` for Intel Core replies.
class IntelListingCard extends StatelessWidget {
  const IntelListingCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final id = data['id']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'Listing';
    final city = data['city']?.toString() ?? '';
    final price = data['price'];
    final images = data['images'];
    final image =
        data['image']?.toString() ??
        (images is List && images.isNotEmpty ? images.first.toString() : null);
    final beds = data['beds'] ?? data['bedrooms'];
    final baths = data['baths'] ?? data['bathrooms'];
    final type = data['listing_type']?.toString();
    final meta = [
      if (beds != null) '$beds bd',
      if (baths != null) '$baths ba',
      if (city.isNotEmpty) city,
    ].join(' · ');

    return GestureDetector(
      onTap: id.isEmpty
          ? null
          : () {
              AppHaptics.selection();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListingDetailScreen(listingId: id),
                ),
              );
            },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null && image.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: CachedNetworkImage(
  imageUrl: image,
                  fit: BoxFit.cover,
                  cacheWidth: 640,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF16161C)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${price ?? 0}${type != null ? ' / $type' : ''}',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.brandPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
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
  }
}

class IntelProfileCard extends StatelessWidget {
  const IntelProfileCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final id = data['id']?.toString() ?? '';
    final name = (data['name']?.toString() ?? 'User').split(' ').first;
    final age = data['age'];
    final city = data['city']?.toString() ?? data['location']?.toString() ?? '';
    final images = data['images'];
    final image =
        data['image']?.toString() ??
        (images is List && images.isNotEmpty ? images.first.toString() : null);

    return GestureDetector(
      onTap: id.isEmpty
          ? null
          : () {
              AppHaptics.selection();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileDetailScreen(userId: id),
                ),
              );
            },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null && image.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: CachedNetworkImage(
  imageUrl: image,
                  fit: BoxFit.cover,
                  cacheWidth: 640,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF16161C)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    age != null ? '$name, $age' : name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (city.isNotEmpty)
                    Text(
                      city,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
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
  }
}
