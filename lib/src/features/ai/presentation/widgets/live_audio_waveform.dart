import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact microphone waveform used by SWIPESS AI voice inputs.
///
/// New amplitude samples enter from the right and older samples move left, so
/// the recording state is always visually obvious. Real microphone amplitude
/// controls the dominant bar height; a tiny idle motion keeps the visual alive
/// between syllables without pretending there is speech.
class LiveAudioWaveform extends StatefulWidget {
  const LiveAudioWaveform({
    super.key,
    required this.active,
    required this.level,
    required this.color,
    this.width = 84,
    this.height = 20,
    this.samples = 28,
  });

  final bool active;
  final double level;
  final Color color;
  final double width;
  final double height;
  final int samples;

  @override
  State<LiveAudioWaveform> createState() => _LiveAudioWaveformState();
}

class _LiveAudioWaveformState extends State<LiveAudioWaveform> {
  Timer? _timer;
  late List<double> _history;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _history = List<double>.filled(math.max(8, widget.samples), .04);
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant LiveAudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples != widget.samples) {
      _history = List<double>.filled(math.max(8, widget.samples), .04);
    }
    if (oldWidget.active != widget.active) _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!widget.active) return;

    _timer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (!mounted || !widget.active) return;
      _phase += .67;

      final live = widget.level.clamp(0.0, 1.0).toDouble();
      final idle = .045 + ((math.sin(_phase) + 1) * .018);
      final texture = .78 + ((math.sin(_phase * 1.73) + 1) * .11);
      final next = (math.max(live, idle) * texture)
          .clamp(.035, 1.0)
          .toDouble();

      setState(() {
        _history = [..._history.skip(1), next];
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _LiveAudioWaveformPainter(
            samples: _history,
            color: widget.color,
            active: widget.active,
          ),
        ),
      ),
    );
  }
}

class _LiveAudioWaveformPainter extends CustomPainter {
  const _LiveAudioWaveformPainter({
    required this.samples,
    required this.color,
    required this.active,
  });

  final List<double> samples;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;

    final step = size.width / samples.length;
    final barWidth = math.max(1.2, math.min(2.5, step * .52));
    final centerY = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < samples.length; i++) {
      final level = Curves.easeOutCubic.transform(
        samples[i].clamp(0.0, 1.0).toDouble(),
      );
      final barHeight = 3 + ((size.height - 3) * level);
      final progress = samples.length <= 1 ? 1.0 : i / (samples.length - 1);
      final alpha = active ? (85 + (170 * progress)).round() : 55;
      paint.color = color.withAlpha(alpha.clamp(0, 255));

      final rect = Rect.fromCenter(
        center: Offset((i + .5) * step, centerY),
        width: barWidth,
        height: barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveAudioWaveformPainter oldDelegate) => true;
}
