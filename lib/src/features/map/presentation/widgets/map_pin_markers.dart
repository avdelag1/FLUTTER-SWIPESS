import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact listing marker: photo and title share one physical pill.
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

  static const double width = 132;
  static const double height = 40;

  /// Geographic point sits on the bottom-center of the photo (not the pill).
  static const Alignment anchor = Alignment(-0.72, 1);

  @override
  Widget build(BuildContext context) {
    final label = title.length > 16 ? '${title.substring(0, 14)}…' : title;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(4, 4, 9, 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xE6111318) : Colors.white.withAlpha(232),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFFFF6B35) : Colors.white.withAlpha(235),
          width: selected ? 1.4 : 0.8,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 7, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _PhotoDot(imageUrl: imageUrl, selected: selected),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : const Color(0xFF111318),
                fontWeight: FontWeight.w800,
                fontSize: 9.5,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoDot extends StatelessWidget {
  const _PhotoDot({required this.imageUrl, required this.selected});

  final String? imageUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE9EAED),
        border: Border.all(
          color: selected ? const Color(0xFFFF6B35) : Colors.white,
          width: 1.5,
        ),
        image: imageUrl == null || imageUrl!.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              ),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Icon(Icons.home_rounded, color: Color(0xFF111318), size: 14)
          : null,
    );
  }
}

/// People pin — circular avatar with restrained brand ring.
class MapProfilePinMarker extends StatelessWidget {
  const MapProfilePinMarker({super.key, this.imageUrl, this.selected = false});

  final String? imageUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 38.0 : 32.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A0A12),
        border: Border.all(
          color: selected ? const Color(0xFFFF6B35) : Colors.white.withAlpha(180),
          width: selected ? 2.2 : 1.6,
        ),
        image: imageUrl == null || imageUrl!.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              ),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 15)
          : null,
    );
  }
}

/// Cluster count bubble.
class MapClusterMarker extends StatelessWidget {
  const MapClusterMarker({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final size = count >= 10 ? 42.0 : 36.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xD9111318),
          border: Border.all(color: Colors.white.withAlpha(200), width: 1.5),
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
