import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Cap AI search light: quiet most of the time, then a ~1s snap
/// every 10 seconds — inner sheen plus outline hotspot, then dark again.
class SearchFrameShine extends StatefulWidget {
  const SearchFrameShine({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  /// Full loop. Shine occupies the first [shineFraction] of this.
  @visibleForTesting
  static const Duration cycle = Duration(seconds: 8);

  /// First 4% of the cycle (400ms) is the snap. The rest is dark.
  @visibleForTesting
  static const double shineFraction = 0.25;

  @visibleForTesting
  static bool isShineWindow(double progress) =>
      progress >= 0 && progress <= shineFraction;

  @override
  State<SearchFrameShine> createState() => _SearchFrameShineState();
}

class _SearchFrameShineState extends State<SearchFrameShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle;

  @override
  void initState() {
    super.initState();
    _cycle = AnimationController(vsync: this, duration: SearchFrameShine.cycle)
      ..repeat();
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,

        Positioned(
          left: -2,
          right: -2,
          top: -2,
          bottom: -2,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _cycle,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FrameShinePainter(
                    progress: _cycle.value,
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
  _InnerSheenPainter({required this.progress, required this.color});

  /// 0–1 over a 10s cycle. Shine lives in the first 10% (~1s).
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (!SearchFrameShine.isShineWindow(progress)) return;

    final local = (progress / SearchFrameShine.shineFraction).clamp(0.0, 1.0);
    final envelope = math.sin(local * math.pi);
    if (envelope <= 0.02) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    final wash = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height * 0.55),
        [
          color.withValues(alpha: 0.22 * envelope),
          Colors.white.withValues(alpha: 0.08 * envelope),
          Colors.transparent,
        ],
        const [0.0, 0.35, 1.0],
      );
    canvas.drawRRect(rrect, wash);

    final x = -size.width * 0.45 + (size.width * 1.9 * local);
    final bladeRect = Rect.fromLTWH(x, -4, size.width * 0.38, size.height + 8);
    final blade = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.linear(
        bladeRect.topLeft,
        bladeRect.topRight,
        [
          Colors.transparent,
          color.withValues(alpha: 0.40 * envelope),
          Colors.white.withValues(alpha: 0.90 * envelope),
          color.withValues(alpha: 0.40 * envelope),
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
  _FrameShinePainter({required this.progress, required this.color});

  /// 0–1 over a 10s cycle. Shine lives in the first 10% (~1s).
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (!SearchFrameShine.isShineWindow(progress)) return;

    final local = (progress / SearchFrameShine.shineFraction).clamp(0.0, 1.0);
    final envelope = math.sin(local * math.pi);
    if (envelope <= 0.02) return;

    final rect = Offset.zero & size;
    const ring = 2.5;
    final shader = SweepGradient(
      transform: GradientRotation(local * math.pi * 2),
      colors: [
        Colors.transparent,
        color.withValues(alpha: 0.25 * envelope),
        Colors.white.withValues(alpha: 0.85 * envelope),
        Colors.white.withValues(alpha: envelope),
        Colors.white.withValues(alpha: 0.85 * envelope),
        Colors.transparent,
      ],
      stops: const [0.0, 0.78, 0.88, 0.93, 0.97, 1.0],
    ).createShader(rect);

    final outer = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    final ringPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(outer.deflate(ring));

    canvas.save();
    canvas.clipPath(ringPath);
    canvas.drawRect(
      rect.inflate(8),
      Paint()
        ..shader = shader
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FrameShinePainter old) =>
      old.progress != progress || old.color != color;
}
