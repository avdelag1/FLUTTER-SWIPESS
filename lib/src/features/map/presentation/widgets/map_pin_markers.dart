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

  static const double width = 154;
  static const double height = 48;

  /// Geographic point sits on the bottom-center of the photo (not the pill).
  static const Alignment anchor = Alignment(-0.72, 1);

  @override
  Widget build(BuildContext context) {
    final label = title.length > 16 ? '${title.substring(0, 14)}…' : title;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF111318) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFFFF4D00) : Colors.white,
          width: selected ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          _PhotoDot(imageUrl: imageUrl, selected: selected),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : const Color(0xFF111318),
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE9EAED),
        border: Border.all(
          color: selected ? const Color(0xFFFF4D00) : Colors.white,
          width: 2,
        ),
        image: imageUrl == null || imageUrl!.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              ),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Icon(Icons.home_rounded, color: Color(0xFF111318), size: 17)
          : null,
    );
  }
}

/// People pin — circular avatar with indigo ring (never a listing title).
class MapProfilePinMarker extends StatelessWidget {
  const MapProfilePinMarker({super.key, this.imageUrl, this.selected = false});

  final String? imageUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 40.0 : 34.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A0A12),
        border: Border.all(
          color: selected ? const Color(0xFFFF4D6A) : const Color(0xFFEC4899),
          width: 2.5,
        ),
        image: imageUrl == null || imageUrl!.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              ),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 16)
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
    final size = count >= 10 ? 46.0 : 38.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111318),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          '$count',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: count >= 100 ? 11 : 13,
          ),
        ),
      ),
    );
  }
}
