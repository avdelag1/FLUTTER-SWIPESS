import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// High-contrast listing marker designed to stay readable over every basemap.
class MapListingPinMarker extends StatelessWidget {
  const MapListingPinMarker({
    super.key,
    required this.title,
    this.imageUrl,
    this.selected = false,
  });

  final String title;
  final String? imageUrl;
  final bool selected;

  static const double width = 146;
  static const double height = 46;
  static const Alignment anchor = Alignment(-0.70, 1);

  @override
  Widget build(BuildContext context) {
    final label = title.length > 17 ? '${title.substring(0, 15)}…' : title;
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: selected ? 1.04 : 1,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111318) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFFFB24A) : const Color(0xFFFF6B35),
            width: selected ? 2.2 : 1.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _ListingPhoto(imageUrl: imageUrl, selected: selected),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LISTING',
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      color: selected
                          ? const Color(0xFFFFB24A)
                          : const Color(0xFFFF5A2F),
                      fontWeight: FontWeight.w900,
                      fontSize: 7.5,
                      letterSpacing: .6,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: selected ? Colors.white : const Color(0xFF111318),
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      letterSpacing: -.05,
                      height: 1.05,
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

class _ListingPhoto extends StatelessWidget {
  const _ListingPhoto({required this.imageUrl, required this.selected});

  final String? imageUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF0F1F3),
        border: Border.all(
          color: selected ? const Color(0xFFFFB24A) : const Color(0xFFFF6B35),
          width: 1.8,
        ),
        image: imageUrl == null || imageUrl!.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
                onError: (_, __) {},
              ),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Icon(
              Icons.home_work_rounded,
              color: Color(0xFF111318),
              size: 17,
            )
          : null,
    );
  }
}

/// Registered-user pin. Fits the map marker hitbox and stays obvious on light
/// and dark tiles with a white halo plus a strong blue center.
class MapProfilePinMarker extends StatelessWidget {
  const MapProfilePinMarker({super.key, this.imageUrl, this.selected = false});

  final String? imageUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 42.0 : 38.0;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: selected ? const Color(0xFF60A5FA) : Colors.white,
          width: selected ? 2.4 : 1.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2463EB),
          border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
          image: imageUrl == null || imageUrl!.isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                  onError: (_, __) {},
                ),
        ),
        child: imageUrl == null || imageUrl!.isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}

class MapClusterMarker extends StatelessWidget {
  const MapClusterMarker({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final size = count >= 10 ? 44.0 : 38.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xE6111318),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8),
          ],
        ),
        child: Text(
          '$count',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: count >= 100 ? 10 : 12,
          ),
        ),
      ),
    );
  }
}
