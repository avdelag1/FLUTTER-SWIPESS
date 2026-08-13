import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Traveling light on the pill **outline only**.
///
/// Rest is a quiet frame. Every 10 seconds a ~1s snap races around the
/// border — no torch behind the bar, no fill inside it.
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle;

  @override
  void initState() {
    super.initState();
    _cycle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
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

class _FrameShinePainter extends CustomPainter {
  _FrameShinePainter({
    required this.progress,
    required this.color,
  });

  /// 0–1 over a 10s cycle. Shine lives in the first 10% (~1s).
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // 0.00–0.10 = the snap. Rest of the cycle is dark.
    if (progress > 0.10) return;

    final local = (progress / 0.10).clamp(0.0, 1.0);
    final envelope = math.sin(local * math.pi);
    if (envelope <= 0.02) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.2),
      Radius.circular(size.height / 2),
    );
    final shader = SweepGradient(
      transform: GradientRotation(local * math.pi * 2),
      colors: [
        Colors.transparent,
        color.withValues(alpha: 0.12 * envelope),
        color.withValues(alpha: 0.95 * envelope),
        Colors.white.withValues(alpha: envelope),
        color.withValues(alpha: 0.95 * envelope),
        Colors.transparent,
      ],
      stops: const [0.0, 0.78, 0.88, 0.93, 0.97, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_FrameShinePainter old) =>
      old.progress != progress || old.color != color;
}
