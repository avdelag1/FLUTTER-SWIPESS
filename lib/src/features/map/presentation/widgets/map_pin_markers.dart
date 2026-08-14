import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap listing pin — white pill with a cyan dot + short title.
class MapListingPinMarker extends StatelessWidget {
  const MapListingPinMarker({
    super.key,
    required this.title,
    this.selected = false,
  });

  final String title;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final label = title.length > 16 ? '${title.substring(0, 14)}…' : title;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFF00C6FF) : const Color(0xFF1D4ED8),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x380F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cap people pin — circular avatar with indigo ring.
class MapProfilePinMarker extends StatelessWidget {
  const MapProfilePinMarker({
    super.key,
    this.imageUrl,
    this.selected = false,
  });

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
        color: const Color(0xFF312E81),
        border: Border.all(
          color: selected ? const Color(0xFFC7D2FE) : Colors.white,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x590F172A), blurRadius: 8),
        ],
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size + 14,
          height: size + 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x5500C6FF),
          ),
        ),
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
            ),
            border: Border.all(color: Colors.white, width: 3),
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
      ],
    );
  }
}
