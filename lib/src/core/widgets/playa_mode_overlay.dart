import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/playa_mode_provider.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Wraps the app and paints the animated playa filter when enabled.
class PlayaModeShell extends ConsumerWidget {
  const PlayaModeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(playaModeProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        PlayaModeOverlay(enabled: enabled),
      ],
    );
  }
}

/// Neon Mayan-cart lines + black-and-white playa atmosphere.
class PlayaModeOverlay extends StatefulWidget {
  const PlayaModeOverlay({super.key, required this.enabled});

  final bool enabled;

  @override
  State<PlayaModeOverlay> createState() => _PlayaModeOverlayState();
}

class _PlayaModeOverlayState extends State<PlayaModeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _visible = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _visible = widget.enabled ? 1 : 0;
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PlayaModeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _visible, end: widget.enabled ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      onEnd: () => _visible = widget.enabled ? 1 : 0,
      builder: (context, opacity, _) {
        if (opacity <= 0.01) return const SizedBox.shrink();
        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _PlayaNeonPainter(phase: _controller.value),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PlayaNeonPainter extends CustomPainter {
  _PlayaNeonPainter({required this.phase});

  final double phase;

  static const _magenta = Color(0xFFFF00E5);
  static const _cyan = Color(0xFF00F0FF);
  static const _ember = Color(0xFFFF6B00);
  static const _lime = Color(0xFF39FF14);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // High-contrast playa wash — pushes UI toward black & white.
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withAlpha(72),
          Colors.white.withAlpha(18),
          Colors.black.withAlpha(110),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [Colors.transparent, Colors.black.withAlpha(140)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    _drawScanlines(canvas, size);
    _drawMayanBands(canvas, size, phase);
    _drawCartSpokes(canvas, size, phase);
    _drawCornerGlyphs(canvas, size, phase);
    _drawHorizonFlame(canvas, size);
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawMayanBands(Canvas canvas, Size size, double t) {
    final bands = [
      (_magenta, 0.12, 0.0),
      (_cyan, 0.10, 0.18),
      (_ember, 0.14, 0.36),
      (_lime, 0.08, 0.55),
      (_cyan, 0.11, 0.72),
    ];
    for (final (color, stroke, offset) in bands) {
      final paint = Paint()
        ..color = color.withAlpha((stroke * 255).round().clamp(18, 90))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      final path = Path();
      final yBase = size.height * (0.18 + offset * 0.55);
      final amp = 10 + offset * 18;
      final wave = 28 + offset * 12;
      final scroll = (t * size.width * 1.4 + offset * 200) % wave;
      path.moveTo(-wave + scroll, yBase);
      for (var x = -wave + scroll; x <= size.width + wave; x += wave / 2) {
        path.lineTo(x, yBase - amp);
        path.lineTo(x + wave / 4, yBase);
        path.lineTo(x + wave / 2, yBase + amp);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawCartSpokes(Canvas canvas, Size size, double t) {
    final hub = Offset(size.width * 0.5, size.height * 1.08);
    final spokes = 16;
    for (var i = 0; i < spokes; i++) {
      final angle = (i / spokes) * math.pi * 2 + t * math.pi * 2;
      final color = i.isEven ? _cyan : _magenta;
      final paint = Paint()
        ..color = color.withAlpha(42)
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final end = hub + Offset(math.cos(angle), math.sin(angle)) * size.height * 0.72;
      canvas.drawLine(hub, end, paint);
    }

    final ringPaint = Paint()
      ..color = _ember.withAlpha(55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      hub,
      size.width * (0.34 + math.sin(t * math.pi * 2) * 0.02),
      ringPaint,
    );
  }

  void _drawCornerGlyphs(Canvas canvas, Size size, double t) {
    const inset = 14.0;
    const len = 34.0;
    final corners = [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ];
    final colors = [_lime, _magenta, _cyan, _ember];
    for (var i = 0; i < corners.length; i++) {
      final c = corners[i];
      final paint = Paint()
        ..color = colors[i].withAlpha(90)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final flicker = math.sin((t + i * 0.25) * math.pi * 4) * 4;
      if (i == 0) {
        canvas.drawLine(c, c + Offset(len + flicker, 0), paint);
        canvas.drawLine(c, c + Offset(0, len + flicker), paint);
      } else if (i == 1) {
        canvas.drawLine(c, c + Offset(-len - flicker, 0), paint);
        canvas.drawLine(c, c + Offset(0, len + flicker), paint);
      } else if (i == 2) {
        canvas.drawLine(c, c + Offset(len + flicker, 0), paint);
        canvas.drawLine(c, c + Offset(0, -len - flicker), paint);
      } else {
        canvas.drawLine(c, c + Offset(-len - flicker, 0), paint);
        canvas.drawLine(c, c + Offset(0, -len - flicker), paint);
      }
    }
  }

  void _drawHorizonFlame(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          _ember.withAlpha(70),
          _magenta.withAlpha(28),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height - 120, size.width, 120));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 120, size.width, 120),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayaNeonPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

/// Header toggle — stick figure + neon ring (Burning Man silhouette).
class PlayaModeToggleButton extends ConsumerStatefulWidget {
  const PlayaModeToggleButton({super.key, required this.inactiveColor});

  final Color inactiveColor;

  @override
  ConsumerState<PlayaModeToggleButton> createState() =>
      _PlayaModeToggleButtonState();
}

class _PlayaModeToggleButtonState extends ConsumerState<PlayaModeToggleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(playaModeProvider);
    if (enabled && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!enabled && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }

    return Semantics(
      button: true,
      label: enabled ? 'Turn off Playa neon filter' : 'Turn on Playa neon filter',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.medium();
          ref.read(playaModeProvider.notifier).toggle();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final glow = enabled ? lerpDouble(0.35, 1, _pulse.value)! : 0.0;
                return CustomPaint(
                  size: const Size(24, 24),
                  painter: _PlayaManIconPainter(
                    active: enabled,
                    glow: glow,
                    inactiveColor: widget.inactiveColor,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayaManIconPainter extends CustomPainter {
  _PlayaManIconPainter({
    required this.active,
    required this.glow,
    required this.inactiveColor,
  });

  final bool active;
  final double glow;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    if (active) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF00F0FF).withAlpha((120 * glow).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glow);
      canvas.drawCircle(Offset(cx, size.height / 2), size.width * 0.46, ring);
    }

    final bodyColor = active
        ? Color.lerp(
            const Color(0xFFFF6B00),
            const Color(0xFFFF00E5),
            glow * 0.5,
          )!
        : inactiveColor;
    stroke.color = bodyColor;

    // Head
    canvas.drawCircle(Offset(cx, 5.5), 2.2, stroke..style = PaintingStyle.stroke);

    // Arms up
    final torsoTop = 8.0;
    final torsoBottom = 14.0;
    canvas.drawLine(Offset(cx, torsoTop), Offset(cx, torsoBottom), stroke);
    canvas.drawLine(Offset(cx, torsoTop + 1), Offset(cx - 5, 4), stroke);
    canvas.drawLine(Offset(cx, torsoTop + 1), Offset(cx + 5, 4), stroke);

    // Legs
    canvas.drawLine(Offset(cx, torsoBottom), Offset(cx - 4, 19), stroke);
    canvas.drawLine(Offset(cx, torsoBottom), Offset(cx + 4, 19), stroke);

    // Playa triangle base
    final tri = Path()
      ..moveTo(cx - 7, 21)
      ..lineTo(cx + 7, 21)
      ..lineTo(cx, 24)
      ..close();
    stroke.style = PaintingStyle.stroke;
    canvas.drawPath(tri, stroke);

    if (active) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFF00E5).withAlpha((90 * glow).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * glow);
      canvas.drawCircle(Offset(cx, 12), 6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlayaManIconPainter oldDelegate) =>
      oldDelegate.active != active ||
      oldDelegate.glow != glow ||
      oldDelegate.inactiveColor != inactiveColor;
}
