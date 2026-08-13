import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Cap `.neo-search-frame-glow` plus an inner traveling sheen.
///
/// Frame: a 3.6s conic hotspot racing around the pill outline.
/// Inside: a soft blue-white blade that sweeps the well so the AI bar
/// actually lights up, not just its border.
class SearchFrameShine extends StatefulWidget {
  const SearchFrameShine({
    super.key,
    required this.child,
    required this.color,
  });

  final Widget child;
  final Color color;

  @override
  State<SearchFrameShine> createState() => _SearchFrameShineState();
}

class _SearchFrameShineState extends State<SearchFrameShine>
    with TickerProviderStateMixin {
  late final AnimationController _frame;
  late final AnimationController _inner;

  @override
  void initState() {
    super.initState();
    _frame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _inner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _frame.dispose();
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: AnimatedBuilder(
                animation: _inner,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _InnerSheenPainter(
                      progress: _inner.value,
                      color: widget.color,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: -2,
          right: -2,
          top: -2,
          bottom: -2,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _frame,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FrameShinePainter(
                    progress: _frame.value,
                    color: widget.color,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _InnerSheenPainter extends CustomPainter {
  _InnerSheenPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    // Ambient wash along the top lip — glass catch-light.
    final wash = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height * 0.55),
        [
          color.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        const [0.0, 0.35, 1.0],
      );
    canvas.drawRRect(rrect, wash);

    // Traveling blade inside the well.
    final x = -size.width * 0.45 + (size.width * 1.9 * progress);
    final bladeRect = Rect.fromLTWH(
      x,
      -4,
      size.width * 0.38,
      size.height + 8,
    );
    final blade = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.linear(
        bladeRect.topLeft,
        bladeRect.topRight,
        [
          Colors.transparent,
          color.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.42),
          color.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        const [0.0, 0.32, 0.5, 0.68, 1.0],
      );
    canvas.drawRect(bladeRect, blade);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerSheenPainter old) =>
      old.progress != progress || old.color != color;
}

class _FrameShinePainter extends CustomPainter {
  _FrameShinePainter({
    required this.progress,
    required this.color,
  });

  /// 0–1 over a 3.6s spin, matching Cap `neo-search-glow-spin`.
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.2),
      Radius.circular(size.height / 2),
    );
    final shader = SweepGradient(
      transform: GradientRotation(progress * math.pi * 2),
      colors: [
        Colors.transparent,
        color.withValues(alpha: 0.08),
        color.withValues(alpha: 0.95),
        Colors.white,
        color.withValues(alpha: 0.95),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0.0, 0.78, 0.88, 0.93, 0.97, 0.995, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_FrameShinePainter old) =>
      old.progress != progress || old.color != color;
}
