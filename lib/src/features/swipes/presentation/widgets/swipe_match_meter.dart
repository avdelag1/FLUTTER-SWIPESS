import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `SwipeMatchMeter` — glass pill + conic ring on the swipe card.
class SwipeMatchMeter extends StatelessWidget {
  const SwipeMatchMeter({
    super.key,
    required this.percentage,
    this.compact = true,
  });

  final int percentage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (percentage <= 0) return const SizedBox.shrink();

    final color = percentage >= 90
        ? const Color(0xFF34D399)
        : percentage >= 75
        ? const Color(0xFF22D3EE)
        : percentage >= 55
        ? const Color(0xFF60A5FA)
        : const Color(0xFFFBBF24);
    final glow = color.withAlpha(70);
    final icon = percentage >= 90
        ? Icons.star_rounded
        : percentage >= 75
        ? Icons.local_fire_department_rounded
        : percentage >= 55
        ? Icons.bolt_rounded
        : Icons.auto_awesome_rounded;
    final label = percentage >= 90
        ? 'Perfect'
        : percentage >= 75
        ? 'Great'
        : percentage >= 55
        ? 'Good'
        : 'Match';

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xAD000000),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withAlpha(64)),
          boxShadow: [BoxShadow(color: glow, blurRadius: 12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              '$percentage%',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(
            painter: _ConicRingPainter(percentage: percentage, color: color),
            child: Center(
              child: Text(
                '$percentage',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x9E000000),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withAlpha(48)),
            boxShadow: [BoxShadow(color: glow, blurRadius: 16)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                '$label Match'.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConicRingPainter extends CustomPainter {
  const _ConicRingPainter({required this.percentage, required this.color});

  final int percentage;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final track = Paint()
      ..color = Colors.white.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 2, track);

    final sweep = (percentage.clamp(0, 100) / 100) * 2 * math.pi;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );

    final fill = Paint()..color = const Color(0xD1000000);
    canvas.drawCircle(center, radius - 6, fill);
  }

  @override
  bool shouldRepaint(covariant _ConicRingPainter oldDelegate) =>
      oldDelegate.percentage != percentage || oldDelegate.color != color;
}
