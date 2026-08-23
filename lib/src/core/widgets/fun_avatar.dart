import 'package:flutter/material.dart';

/// Temporary deterministic avatar used only when a user has not uploaded a
/// real profile photo yet. The same seed always gets the same character, so
/// avatars do not jump around between sessions.
///
/// We intentionally do not infer gender, ethnicity, age, or any other personal
/// trait from a user's name. A real uploaded photo always wins over this
/// fallback.
class FunAvatar extends StatelessWidget {
  const FunAvatar({
    super.key,
    required this.seed,
    this.imageUrl,
    this.size = 44,
    this.semanticLabel,
    this.borderRadius,
  });

  final String seed;
  final String? imageUrl;
  final double size;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  int get _variant => _stableHash(seed) % 10;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 2);
    final fallback = _fallback(radius);
    final url = imageUrl?.trim();

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Profile avatar',
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: size,
          height: size,
          child: url == null || url.isEmpty
              ? fallback
              : Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }

  Widget _fallback(BorderRadius radius) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _FunAvatarPainter(variant: _variant),
      ),
    );
  }

  static int _stableHash(String input) {
    var hash = 0x811C9DC5;
    final normalized = input.trim().toLowerCase().isEmpty
        ? 'swipess-resident'
        : input.trim().toLowerCase();
    for (final unit in normalized.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class _FunAvatarPainter extends CustomPainter {
  const _FunAvatarPainter({required this.variant});

  final int variant;

  static const _backgrounds = <List<Color>>[
    [Color(0xFFFF6B35), Color(0xFFEB4898)],
    [Color(0xFF06B6D4), Color(0xFF6366F1)],
    [Color(0xFFFFC857), Color(0xFFFF4D00)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFF10B981), Color(0xFF0F766E)],
    [Color(0xFF38BDF8), Color(0xFF2563EB)],
    [Color(0xFFF472B6), Color(0xFF7C3AED)],
    [Color(0xFFF59E0B), Color(0xFFDC2626)],
    [Color(0xFF22D3EE), Color(0xFF0F172A)],
    [Color(0xFFE879F9), Color(0xFF312E81)],
  ];

  static const _skin = <Color>[
    Color(0xFFF6C7A4),
    Color(0xFFD99A72),
    Color(0xFF9A6044),
    Color(0xFFF1B58D),
    Color(0xFF6F4434),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = _backgrounds[variant % _backgrounds.length];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bg,
        ).createShader(rect),
    );

    _drawBackdrop(canvas, size);

    final c = Offset(size.width * .5, size.height * .53);
    final faceR = size.width * .29;
    final faceColor = variant == 4
        ? const Color(0xFFB7F774)
        : _skin[variant % _skin.length];

    // Neck + shoulders.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * .5, size.height * .93),
          width: size.width * .78,
          height: size.height * .43,
        ),
        Radius.circular(size.width * .25),
      ),
      Paint()..color = variant.isEven
          ? const Color(0xFF111827)
          : const Color(0xFFF8FAFC),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, size.height * .76),
          width: size.width * .20,
          height: size.height * .25,
        ),
        Radius.circular(size.width * .08),
      ),
      Paint()..color = faceColor,
    );

    // Hair sits behind the face.
    _drawHair(canvas, c, faceR, size);
    canvas.drawCircle(c, faceR, Paint()..color = faceColor);

    // Ears.
    canvas.drawCircle(
      Offset(c.dx - faceR * .92, c.dy + faceR * .02),
      faceR * .16,
      Paint()..color = faceColor,
    );
    canvas.drawCircle(
      Offset(c.dx + faceR * .92, c.dy + faceR * .02),
      faceR * .16,
      Paint()..color = faceColor,
    );

    if (variant == 4) {
      _drawAlienFace(canvas, c, faceR);
      return;
    }

    _drawBrows(canvas, c, faceR);
    _drawEyes(canvas, c, faceR);
    _drawNose(canvas, c, faceR);
    _drawMouth(canvas, c, faceR);
    _drawAccessory(canvas, c, faceR, size);
  }

  void _drawBackdrop(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white.withAlpha(32);
    canvas.drawCircle(
      Offset(size.width * .18, size.height * .18),
      size.width * .11,
      white,
    );
    canvas.drawCircle(
      Offset(size.width * .84, size.height * .28),
      size.width * .055,
      white,
    );
    if (variant == 3 || variant == 8) {
      final star = Path()
        ..moveTo(size.width * .80, size.height * .08)
        ..lineTo(size.width * .83, size.height * .15)
        ..lineTo(size.width * .90, size.height * .18)
        ..lineTo(size.width * .83, size.height * .21)
        ..lineTo(size.width * .80, size.height * .28)
        ..lineTo(size.width * .77, size.height * .21)
        ..lineTo(size.width * .70, size.height * .18)
        ..lineTo(size.width * .77, size.height * .15)
        ..close();
      canvas.drawPath(star, Paint()..color = Colors.white.withAlpha(150));
    }
  }

  void _drawHair(Canvas canvas, Offset c, double r, Size size) {
    final hair = Paint()
      ..color = switch (variant) {
        0 => const Color(0xFF1F2937),
        1 => const Color(0xFF6B3F2A),
        2 => const Color(0xFF2B2118),
        3 => const Color(0xFFF8FAFC),
        5 => const Color(0xFFD97706),
        6 => const Color(0xFF111827),
        7 => const Color(0xFF5B3424),
        8 => const Color(0xFF0F172A),
        9 => const Color(0xFFEC4899),
        _ => const Color(0xFF334155),
      };

    if (variant == 4) return;

    if (variant == 1 || variant == 7) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy - r * .10),
          width: r * 2.25,
          height: r * 2.30,
        ),
        hair,
      );
      return;
    }

    final path = Path()
      ..moveTo(c.dx - r * .98, c.dy - r * .05)
      ..quadraticBezierTo(c.dx - r * .88, c.dy - r * 1.15, c.dx, c.dy - r * 1.22)
      ..quadraticBezierTo(c.dx + r * .95, c.dy - r * 1.05, c.dx + r * .98, c.dy + r * .04)
      ..quadraticBezierTo(c.dx + r * .48, c.dy - r * .75, c.dx, c.dy - r * .66)
      ..quadraticBezierTo(c.dx - r * .48, c.dy - r * .78, c.dx - r * .98, c.dy - r * .05)
      ..close();
    canvas.drawPath(path, hair);

    if (variant == 5) {
      // Surfer bun.
      canvas.drawCircle(Offset(c.dx + r * .58, c.dy - r * .93), r * .30, hair);
    }
  }

  void _drawBrows(Canvas canvas, Offset c, double r) {
    final p = Paint()
      ..color = const Color(0xFF2D211B)
      ..strokeWidth = r * .075
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(c.dx - r * .55, c.dy - r * .18),
      Offset(c.dx - r * .18, c.dy - r * .23),
      p,
    );
    canvas.drawLine(
      Offset(c.dx + r * .18, c.dy - r * .23),
      Offset(c.dx + r * .55, c.dy - r * .18),
      p,
    );
  }

  void _drawEyes(Canvas canvas, Offset c, double r) {
    if (variant == 0 || variant == 6 || variant == 8) {
      final lens = Paint()..color = const Color(0xFF111827);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx - r * .36, c.dy - r * .02),
            width: r * .62,
            height: r * .34,
          ),
          Radius.circular(r * .16),
        ),
        lens,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx + r * .36, c.dy - r * .02),
            width: r * .62,
            height: r * .34,
          ),
          Radius.circular(r * .16),
        ),
        lens,
      );
      canvas.drawLine(
        Offset(c.dx - r * .05, c.dy - r * .02),
        Offset(c.dx + r * .05, c.dy - r * .02),
        Paint()
          ..color = const Color(0xFF111827)
          ..strokeWidth = r * .08,
      );
      final shine = Paint()..color = Colors.white.withAlpha(170);
      canvas.drawCircle(
        Offset(c.dx - r * .46, c.dy - r * .08),
        r * .05,
        shine,
      );
      canvas.drawCircle(
        Offset(c.dx + r * .26, c.dy - r * .08),
        r * .05,
        shine,
      );
      return;
    }

    final eye = Paint()..color = const Color(0xFF171717);
    canvas.drawCircle(Offset(c.dx - r * .34, c.dy - r * .02), r * .075, eye);
    canvas.drawCircle(Offset(c.dx + r * .34, c.dy - r * .02), r * .075, eye);
  }

  void _drawAlienFace(Canvas canvas, Offset c, double r) {
    final eye = Paint()..color = const Color(0xFF111827);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - r * .35, c.dy - r * .08),
        width: r * .34,
        height: r * .52,
      ),
      eye,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx + r * .35, c.dy - r * .08),
        width: r * .34,
        height: r * .52,
      ),
      eye,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(c.dx, c.dy + r * .35), width: r * .52, height: r * .30),
      .15,
      2.8,
      false,
      Paint()
        ..color = const Color(0xFF315D2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .06
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawNose(Canvas canvas, Offset c, double r) {
    canvas.drawLine(
      Offset(c.dx, c.dy + r * .02),
      Offset(c.dx - r * .06, c.dy + r * .25),
      Paint()
        ..color = const Color(0x442D211B)
        ..strokeWidth = r * .055
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawMouth(Canvas canvas, Offset c, double r) {
    if (variant == 2) {
      final moustache = Paint()..color = const Color(0xFF2B2118);
      final left = Path()
        ..moveTo(c.dx, c.dy + r * .38)
        ..quadraticBezierTo(c.dx - r * .20, c.dy + r * .25, c.dx - r * .47, c.dy + r * .39)
        ..quadraticBezierTo(c.dx - r * .20, c.dy + r * .54, c.dx, c.dy + r * .42)
        ..close();
      final right = Path()
        ..moveTo(c.dx, c.dy + r * .38)
        ..quadraticBezierTo(c.dx + r * .20, c.dy + r * .25, c.dx + r * .47, c.dy + r * .39)
        ..quadraticBezierTo(c.dx + r * .20, c.dy + r * .54, c.dx, c.dy + r * .42)
        ..close();
      canvas.drawPath(left, moustache);
      canvas.drawPath(right, moustache);
    }

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * .42),
        width: r * .58,
        height: r * .34,
      ),
      .20,
      2.72,
      false,
      Paint()
        ..color = const Color(0xFF8B3E3E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .07
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawAccessory(Canvas canvas, Offset c, double r, Size size) {
    if (variant == 1) {
      // Boho headband.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy - r * .72),
            width: r * 1.72,
            height: r * .20,
          ),
          Radius.circular(r * .10),
        ),
        Paint()..color = const Color(0xFFFFC857),
      );
      canvas.drawCircle(
        Offset(c.dx, c.dy - r * .72),
        r * .09,
        Paint()..color = const Color(0xFFE4007C),
      );
    } else if (variant == 3) {
      // Space visor.
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy - r * .02),
          width: r * 2.20,
          height: r * 2.16,
        ),
        3.35,
        2.72,
        false,
        Paint()
          ..color = Colors.white.withAlpha(190)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .09,
      );
    } else if (variant == 7) {
      // Wide resort hat.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy - r * .83),
          width: r * 2.15,
          height: r * .34,
        ),
        Paint()..color = const Color(0xFFF2D3A2),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy - r * 1.05),
            width: r * 1.10,
            height: r * .60,
          ),
          Radius.circular(r * .22),
        ),
        Paint()..color = const Color(0xFFF2D3A2),
      );
    } else if (variant == 9) {
      // Futuristic face stripe.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx + r * .52, c.dy + r * .05),
            width: r * .10,
            height: r * .86,
          ),
          Radius.circular(r * .05),
        ),
        Paint()..color = const Color(0xFF06B6D4),
      );
    } else if (variant == 5) {
      // Small shell earring.
      canvas.drawCircle(
        Offset(c.dx + r * 1.00, c.dy + r * .20),
        r * .08,
        Paint()..color = const Color(0xFFFFC857),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FunAvatarPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
