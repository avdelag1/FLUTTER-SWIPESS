import 'package:flutter/material.dart';

/// Mini illustration of a vault document type (passport, ID, license, lease…).
/// Used on the PEARL card when a file is missing, and as a fallback under
/// a blurred live preview when a file is on record.
class DocTypeSpecimen extends StatelessWidget {
  const DocTypeSpecimen({super.key, required this.documentType});

  final String documentType;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DocTypeSpecimenPainter(documentType),
      child: const SizedBox.expand(),
    );
  }
}

class _DocTypeSpecimenPainter extends CustomPainter {
  _DocTypeSpecimenPainter(this.type);
  final String type;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case 'passport':
        _passport(canvas, size);
      case 'government_id':
        _idCard(canvas, size, const Color(0xFF1E3A5F), const Color(0xFF3B82F6));
      case 'drivers_license':
        _idCard(canvas, size, const Color(0xFF3F2A12), const Color(0xFFD4A017));
      case 'six_month_lease':
        _paper(canvas, size, title: 'LEASE', bar: const Color(0xFFB91C1C));
      case 'recommendation':
        _paper(canvas, size, title: 'REF', bar: const Color(0xFF4C1D95));
      default:
        _paper(canvas, size, title: 'DOC', bar: const Color(0xFF525252));
    }
  }

  void _passport(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(6),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF6B1020));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFFC9A227)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final crest = Paint()..color = const Color(0xFFE8C547);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.28),
        width: size.width * 0.34,
        height: size.height * 0.18,
      ),
      crest,
    );
    final title = TextPainter(
      text: const TextSpan(
        text: 'PASSPORT',
        style: TextStyle(
          color: Color(0xFFE8C547),
          fontSize: 6.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    title.paint(
      canvas,
      Offset((size.width - title.width) / 2, size.height * 0.42),
    );
    final photo = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.58,
        size.width * 0.32,
        size.height * 0.32,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(photo, Paint()..color = const Color(0xFF8B2E3E));
    _lines(
      canvas,
      Offset(size.width * 0.5, size.height * 0.62),
      size.width * 0.38,
      4,
      const Color(0xFFC9A227),
    );
  }

  void _idCard(Canvas canvas, Size size, Color bg, Color accent) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(5),
    );
    canvas.drawRRect(r, Paint()..color = bg);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.18),
      Paint()..color = accent,
    );
    final photo = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.28,
        size.width * 0.34,
        size.height * 0.46,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(photo, Paint()..color = Colors.white.withAlpha(40));
    _lines(
      canvas,
      Offset(size.width * 0.48, size.height * 0.32),
      size.width * 0.42,
      5,
      Colors.white.withAlpha(160),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.82,
        size.width * 0.84,
        size.height * 0.1,
      ),
      Paint()..color = Colors.white.withAlpha(50),
    );
  }

  void _paper(
    Canvas canvas,
    Size size, {
    required String title,
    required Color bar,
  }) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(3),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFFF8F4EC));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.16),
      Paint()..color = bar,
    );
    final label = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 6,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    label.paint(canvas, Offset((size.width - label.width) / 2, 2));
    _lines(
      canvas,
      Offset(size.width * 0.1, size.height * 0.28),
      size.width * 0.8,
      7,
      const Color(0xFF9CA3AF),
    );
    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.9),
      Offset(size.width * 0.88, size.height * 0.9),
      Paint()
        ..color = bar.withAlpha(140)
        ..strokeWidth = 1,
    );
  }

  void _lines(
    Canvas canvas,
    Offset origin,
    double width,
    int count,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1;
    for (var i = 0; i < count; i++) {
      final y = origin.dy + i * 5.2;
      final w = i == count - 1 ? width * 0.55 : width;
      canvas.drawLine(
        origin.translate(0, y - origin.dy),
        origin.translate(w, y - origin.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DocTypeSpecimenPainter oldDelegate) =>
      oldDelegate.type != type;
}
