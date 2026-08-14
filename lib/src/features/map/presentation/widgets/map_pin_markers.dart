import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Listing pin: circular photo + title pill as one marker, anchored on the photo.
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

  static const double width = 196;
  static const double height = 56;

  /// Geographic point sits on the bottom-center of the photo (not the pill).
  static const Alignment anchor = Alignment(-0.74, 1);

  @override
  Widget build(BuildContext context) {
    final label = title.length > 16 ? '${title.substring(0, 14)}…' : title;
    final ring = selected ? const Color(0xFFFF6B35) : const Color(0xFFFF4D00);
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PhotoDot(imageUrl: imageUrl, selected: selected, ring: ring),
          Transform.translate(
            offset: const Offset(-8, -6),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 140),
              padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ring, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: ring.withAlpha(selected ? 140 : 70),
                    blurRadius: selected ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: selected ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoDot extends StatelessWidget {
  const _PhotoDot({
    required this.imageUrl,
    required this.selected,
    required this.ring,
  });

  final String? imageUrl;
  final bool selected;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 48.0 : 44.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF4D00), Color(0xFFE4007C)],
            ),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: ring.withAlpha(160),
                blurRadius: 12,
              ),
            ],
            image: imageUrl == null || imageUrl!.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        CustomPaint(
          size: const Size(10, 7),
          painter: _PinTipPainter(color: ring),
        ),
      ],
    );
  }
}

class _PinTipPainter extends CustomPainter {
  _PinTipPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// People pin — circular avatar with indigo ring (never a listing title).
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
        boxShadow: const [
          BoxShadow(color: Color(0x66E4007C), blurRadius: 10),
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
            color: Color(0x55FF4D00),
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
              colors: [Color(0xFFFF4D00), Color(0xFFE4007C)],
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
