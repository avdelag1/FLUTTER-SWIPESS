import 'dart:math' as math;

import 'package:flutter/material.dart';

class _Star {
  const _Star({
    required this.dx,
    required this.dy,
    required this.size,
    required this.baseOpacity,
    required this.twinkleSpeed,
    required this.phase,
    required this.glow,
  });

  final double dx;
  final double dy;
  final double size;
  final double baseOpacity;
  final double twinkleSpeed;
  final double phase;
  final bool glow;
}

class _ShootingStar {
  const _ShootingStar({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.length,
    required this.born,
    required this.life,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double length;
  final double born;
  final double life;
}

/// Night-sky canvas used on the access gate, welcome, and auth screens.
class StarfieldBackground extends StatefulWidget {
  const StarfieldBackground({super.key});

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_Star> _stars;
  final List<_ShootingStar> _shots = [];
  final math.Random _rng = math.Random(7);
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _stars = const [];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _controller.addListener(_maybeSpawnShot);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _seed(Size size) {
    if (size == _size && _stars.isNotEmpty) return;
    _size = size;
    final count = math.min(180, (size.width * size.height / 2800).round());
    _stars = List.generate(count, (_) {
      return _Star(
        dx: _rng.nextDouble(),
        dy: _rng.nextDouble(),
        size: 0.4 + _rng.nextDouble() * 1.4,
        baseOpacity: 0.28 + _rng.nextDouble() * 0.55,
        twinkleSpeed: 0.6 + _rng.nextDouble() * 1.8,
        phase: _rng.nextDouble() * math.pi * 2,
        glow: _rng.nextDouble() > 0.86,
      );
    });
  }

  void _maybeSpawnShot() {
    if (!mounted || _size == Size.zero) return;
    _shots.removeWhere((s) {
      var age = _controller.value - s.born;
      if (age < 0) age += 1;
      return age > s.life;
    });
    if (_shots.length >= 2) return;
    if (_rng.nextDouble() > 0.018) return;
    _shots.add(
      _ShootingStar(
        x: _rng.nextDouble() * _size.width,
        y: _rng.nextDouble() * _size.height * 0.45,
        vx: 180 + _rng.nextDouble() * 220,
        vy: 70 + _rng.nextDouble() * 90,
        length: 48 + _rng.nextDouble() * 70,
        born: _controller.value,
        life: 0.08 + _rng.nextDouble() * 0.06,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _StarfieldPainter(
                stars: _stars,
                shots: _shots,
                t: _controller.value,
                seeder: _seed,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({
    required this.stars,
    required this.shots,
    required this.t,
    required this.seeder,
  });

  final List<_Star> stars;
  final List<_ShootingStar> shots;
  final double t;
  final void Function(Size size) seeder;

  @override
  void paint(Canvas canvas, Size size) {
    seeder(size);
    final time = t * math.pi * 2;

    for (final star in stars) {
      final twinkle =
          0.55 + 0.45 * math.sin(time * star.twinkleSpeed + star.phase);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: star.baseOpacity * twinkle);
      final offset = Offset(star.dx * size.width, star.dy * size.height);
      canvas.drawCircle(offset, star.size, paint);
      if (star.glow) {
        canvas.drawCircle(
          offset,
          star.size * 3.2,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.08 * twinkle)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    for (final shot in shots) {
      var age = t - shot.born;
      if (age < 0) age += 1;
      final progress = (age / shot.life).clamp(0.0, 1.0);
      final x = shot.x + shot.vx * progress;
      final y = shot.y + shot.vy * progress;
      final opacity = (1 - progress) * 0.9;
      final p1 = Offset(x, y);
      final p2 = Offset(x - shot.length, y - shot.length * 0.35);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => true;
}
