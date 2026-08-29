import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/playa_mode_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Neon palette — playa / arcade energy.
abstract final class PlayaColors {
  static const ember = Color(0xFFFF5500);
  static const flame = Color(0xFFFF8A00);
  static const gold = Color(0xFFFFD000);
  static const magenta = Color(0xFFFF00E5);
  static const cyan = Color(0xFF00F0FF);
  static const lime = Color(0xFF39FF14);

  static const neon = [ember, flame, gold, magenta, cyan, lime];
}

/// Wraps the app and paints fast arcade lights when playa mode is on.
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
        PlayaLiveLightsOverlay(enabled: enabled),
      ],
    );
  }
}

/// Fast random neon streaks — game-border energy, no shade wash.
class PlayaLiveLightsOverlay extends StatefulWidget {
  const PlayaLiveLightsOverlay({super.key, required this.enabled});

  final bool enabled;

  @override
  State<PlayaLiveLightsOverlay> createState() => _PlayaLiveLightsOverlayState();
}

class _LightParticle {
  _LightParticle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.trail,
  });

  Offset pos;
  Offset vel;
  Color color;
  final List<Offset> trail;
}

class _PlayaLiveLightsOverlayState extends State<PlayaLiveLightsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  final _rng = math.Random(42);
  final List<_LightParticle> _particles = [];
  double _fade = 0;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    );
    _fade = widget.enabled ? 1 : 0;
    if (widget.enabled) _start();
  }

  void _start() {
    _tick.repeat();
  }

  void _seedParticles(Size size) {
    if (_particles.isNotEmpty || size.isEmpty) return;
    for (var i = 0; i < 14; i++) {
      final edge = _rng.nextInt(4);
      final pos = switch (edge) {
        0 => Offset(_rng.nextDouble() * size.width, 0),
        1 => Offset(size.width, _rng.nextDouble() * size.height),
        2 => Offset(_rng.nextDouble() * size.width, size.height),
        _ => Offset(0, _rng.nextDouble() * size.height),
      };
      final speed = 180 + _rng.nextDouble() * 320;
      final angle = _rng.nextDouble() * math.pi * 2;
      _particles.add(
        _LightParticle(
          pos: pos,
          vel: Offset(math.cos(angle), math.sin(angle)) * speed,
          color: PlayaColors.neon[i % PlayaColors.neon.length],
          trail: [],
        ),
      );
    }
  }

  void _step(Size size, double dt) {
    for (final p in _particles) {
      p.pos += p.vel * dt;
      p.trail.insert(0, p.pos);
      if (p.trail.length > 6) p.trail.removeLast();

      if (p.pos.dx < 0 || p.pos.dx > size.width) {
        p.vel = Offset(-p.vel.dx, p.vel.dy);
        p.pos = Offset(p.pos.dx.clamp(0, size.width), p.pos.dy);
      }
      if (p.pos.dy < 0 || p.pos.dy > size.height) {
        p.vel = Offset(p.vel.dx, -p.vel.dy);
        p.pos = Offset(p.pos.dx, p.pos.dy.clamp(0, size.height));
      }

      if (_rng.nextDouble() < 0.018) {
        final nudge = (_rng.nextDouble() - 0.5) * 420;
        p.vel += Offset(nudge, (_rng.nextDouble() - 0.5) * 420);
        final max = 520.0;
        if (p.vel.distance > max) p.vel = p.vel / p.vel.distance * max;
      }
    }
  }

  @override
  void didUpdateWidget(covariant PlayaLiveLightsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _particles.clear();
      _start();
    } else if (!widget.enabled && oldWidget.enabled) {
      _tick.stop();
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _fade, end: widget.enabled ? 1 : 0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      onEnd: () => _fade = widget.enabled ? 1 : 0,
      builder: (context, opacity, _) {
        if (opacity <= 0.01) return const SizedBox.shrink();
        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                _seedParticles(size);
                return AnimatedBuilder(
                  animation: _tick,
                  builder: (context, _) {
                    _step(size, 1 / 60);
                    return CustomPaint(
                      size: size,
                      painter: _ArcadeLightsPainter(
                        particles: _particles,
                        framePhase: _tick.value,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ArcadeLightsPainter extends CustomPainter {
  _ArcadeLightsPainter({
    required this.particles,
    required this.framePhase,
  });

  final List<_LightParticle> particles;
  final double framePhase;

  @override
  void paint(Canvas canvas, Size size) {
    _drawScreenFrame(canvas, size, framePhase);
    for (final p in particles) {
      for (var i = 0; i < p.trail.length; i++) {
        final alpha = ((1 - i / p.trail.length) * 90).round();
        final trailPaint = Paint()
          ..color = p.color.withAlpha(alpha)
          ..strokeWidth = 2.2 - i * 0.25
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        if (i + 1 < p.trail.length) {
          canvas.drawLine(p.trail[i], p.trail[i + 1], trailPaint);
        }
      }
      final core = Paint()
        ..color = p.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(p.pos, 3.2, core);
      final halo = Paint()
        ..color = p.color.withAlpha(55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(p.pos, 9, halo);
    }
  }

  void _drawScreenFrame(Canvas canvas, Size size, double t) {
    const inset = 6.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final perimeter = (rect.width + rect.height) * 2;
    final travel = (t * perimeter * 3.5) % perimeter;
    final runner = _pointOnRectPerimeter(rect, travel);
    final runnerPaint = Paint()
      ..color = PlayaColors.cyan
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(runner, 5, runnerPaint);
    canvas.drawCircle(runner, 12, runnerPaint..color = PlayaColors.magenta.withAlpha(40));

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = PlayaColors.ember.withAlpha(45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      border,
    );

    final cornerLen = 28.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    final cornerColors = [PlayaColors.lime, PlayaColors.magenta, PlayaColors.cyan, PlayaColors.gold];
    for (var i = 0; i < corners.length; i++) {
      final c = corners[i];
      final flicker = math.sin((t * 8 + i) * math.pi) * 0.5 + 0.5;
      final paint = Paint()
        ..color = cornerColors[i].withAlpha((60 + flicker * 80).round())
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      if (i == 0) {
        canvas.drawLine(c, c + Offset(cornerLen, 0), paint);
        canvas.drawLine(c, c + Offset(0, cornerLen), paint);
      } else if (i == 1) {
        canvas.drawLine(c, c + Offset(-cornerLen, 0), paint);
        canvas.drawLine(c, c + Offset(0, cornerLen), paint);
      } else if (i == 2) {
        canvas.drawLine(c, c + Offset(cornerLen, 0), paint);
        canvas.drawLine(c, c + Offset(0, -cornerLen), paint);
      } else {
        canvas.drawLine(c, c + Offset(-cornerLen, 0), paint);
        canvas.drawLine(c, c + Offset(0, -cornerLen), paint);
      }
    }
  }

  Offset _pointOnRectPerimeter(Rect r, double d) {
    final w = r.width;
    final h = r.height;
    if (d < w) return Offset(r.left + d, r.top);
    d -= w;
    if (d < h) return Offset(r.right, r.top + d);
    d -= h;
    if (d < w) return Offset(r.right - d, r.bottom);
    d -= w;
    return Offset(r.left, r.bottom - d);
  }

  @override
  bool shouldRepaint(covariant _ArcadeLightsPainter oldDelegate) => true;
}

enum _PlayaShape { circle, triangle, diamond, hexagon, squircle }

/// Racing neon frame + random shape morph for HUD buttons and dock icons.
class PlayaChromeFrame extends ConsumerStatefulWidget {
  const PlayaChromeFrame({
    super.key,
    required this.child,
    required this.size,
    this.seed = 0,
    this.enabled,
  });

  final Widget child;
  final double size;
  final int seed;
  final bool? enabled;

  @override
  ConsumerState<PlayaChromeFrame> createState() => _PlayaChromeFrameState();
}

class _PlayaChromeFrameState extends ConsumerState<PlayaChromeFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _runner;
  int _shapeEpoch = 0;

  @override
  void initState() {
    super.initState();
    _runner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _scheduleShapeShift();
  }

  void _scheduleShapeShift() {
    Future<void>.delayed(
      Duration(milliseconds: 2200 + (widget.seed % 5) * 400),
      () {
        if (!mounted) return;
        final bool on = widget.enabled ?? ref.read(playaModeProvider);
        if (on) setState(() => _shapeEpoch++);
        _scheduleShapeShift();
      },
    );
  }

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  _PlayaShape get _shape {
    final shapes = _PlayaShape.values;
    return shapes[(widget.seed + _shapeEpoch) % shapes.length];
  }

  @override
  Widget build(BuildContext context) {
    final bool on = widget.enabled ?? ref.watch(playaModeProvider);
    if (!on) return widget.child;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _runner,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _ChromeRunnerPainter(
              phase: _runner.value,
              shape: _shape,
              seed: widget.seed,
            ),
            child: ClipPath(
              clipper: _PlayaShapeClipper(shape: _shape, inset: 4),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _PlayaShapeClipper extends CustomClipper<Path> {
  _PlayaShapeClipper({required this.shape, required this.inset});

  final _PlayaShape shape;
  final double inset;

  @override
  Path getClip(Size size) {
    final rect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = rect.shortestSide / 2;
    return switch (shape) {
      _PlayaShape.circle => Path()..addOval(rect),
      _PlayaShape.triangle => Path()
        ..moveTo(cx, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close(),
      _PlayaShape.diamond => Path()
        ..moveTo(cx, rect.top)
        ..lineTo(rect.right, cy)
        ..lineTo(cx, rect.bottom)
        ..lineTo(rect.left, cy)
        ..close(),
      _PlayaShape.hexagon => _hexPath(cx, cy, r),
      _PlayaShape.squircle => Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.35))),
    };
  }

  Path _hexPath(double cx, double cy, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final p = Offset(cx + math.cos(angle) * radius, cy + math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _PlayaShapeClipper oldClipper) =>
      oldClipper.shape != shape;
}

class _ChromeRunnerPainter extends CustomPainter {
  _ChromeRunnerPainter({
    required this.phase,
    required this.shape,
    required this.seed,
  });

  final double phase;
  final _PlayaShape shape;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = 3.0;
    final rect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final color = PlayaColors.neon[(seed + (phase * 6).floor()) % PlayaColors.neon.length];

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = color.withAlpha(70);
    _strokeShape(canvas, rect, size, border);

    final runnerPos = _pointOnShape(shape, rect, phase);
    final glow = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(runnerPos, 3.5, glow);
    canvas.drawCircle(runnerPos, 8, glow..color = color.withAlpha(45));

    final trailPaint = Paint()
      ..color = color.withAlpha(120)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final trailStart = _pointOnShape(shape, rect, (phase - 0.08).clamp(0.0, 1.0));
    canvas.drawLine(trailStart, runnerPos, trailPaint);
  }

  void _strokeShape(Canvas canvas, Rect rect, Size size, Paint paint) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final r = rect.shortestSide / 2;
    switch (shape) {
      case _PlayaShape.circle:
        canvas.drawCircle(rect.center, r, paint);
      case _PlayaShape.squircle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(r * 0.35)),
          paint,
        );
      case _PlayaShape.triangle:
        final path = Path()
          ..moveTo(cx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, paint);
      case _PlayaShape.diamond:
        final path = Path()
          ..moveTo(cx, rect.top)
          ..lineTo(rect.right, cy)
          ..lineTo(cx, rect.bottom)
          ..lineTo(rect.left, cy)
          ..close();
        canvas.drawPath(path, paint);
      case _PlayaShape.hexagon:
        canvas.drawPath(_PlayaShapeClipper(shape: shape, inset: 0).getClip(size), paint);
    }
  }

  Offset _pointOnShape(_PlayaShape shape, Rect rect, double t) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final r = rect.shortestSide / 2;
    return switch (shape) {
      _PlayaShape.circle => Offset(
          cx + math.cos(t * math.pi * 2) * r,
          cy + math.sin(t * math.pi * 2) * r,
        ),
      _PlayaShape.triangle => _edgeLerp([
          Offset(cx, rect.top),
          Offset(rect.right, rect.bottom),
          Offset(rect.left, rect.bottom),
          Offset(cx, rect.top),
        ], t),
      _PlayaShape.diamond => _edgeLerp([
          Offset(cx, rect.top),
          Offset(rect.right, cy),
          Offset(cx, rect.bottom),
          Offset(rect.left, cy),
          Offset(cx, rect.top),
        ], t),
      _PlayaShape.hexagon => () {
          final pts = List.generate(7, (i) {
            if (i == 6) return Offset(cx + math.cos(-math.pi / 2) * r, cy + math.sin(-math.pi / 2) * r);
            final angle = (math.pi / 3) * i - math.pi / 2;
            return Offset(cx + math.cos(angle) * r, cy + math.sin(angle) * r);
          });
          return _edgeLerp(pts, t);
        }(),
      _PlayaShape.squircle => _pointOnRectPerimeter(rect, t * (rect.width + rect.height) * 2),
    };
  }

  Offset _edgeLerp(List<Offset> pts, double t) {
    final total = pts.length - 1;
    final seg = (t * total).floor().clamp(0, total - 1);
    final local = (t * total) - seg;
    return Offset.lerp(pts[seg], pts[seg + 1], local)!;
  }

  Offset _pointOnRectPerimeter(Rect r, double d) {
    final w = r.width;
    final h = r.height;
    if (d < w) return Offset(r.left + d, r.top);
    d -= w;
    if (d < h) return Offset(r.right, r.top + d);
    d -= h;
    if (d < w) return Offset(r.right - d, r.bottom);
    d -= w;
    return Offset(r.left, r.bottom - d);
  }

  @override
  bool shouldRepaint(covariant _ChromeRunnerPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.shape != shape;
}

/// Moon/sun button — tap toggles theme, long-press toggles playa neon.
/// When playa is on the icon becomes a live flame in ember colors.
class ThemePlayaHudButton extends ConsumerStatefulWidget {
  const ThemePlayaHudButton({
    super.key,
    required this.ink,
    required this.isLight,
  });

  final Color ink;
  final bool isLight;

  @override
  ConsumerState<ThemePlayaHudButton> createState() =>
      _ThemePlayaHudButtonState();
}

class _ThemePlayaHudButtonState extends ConsumerState<ThemePlayaHudButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flame;

  @override
  void initState() {
    super.initState();
    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playa = ref.watch(playaModeProvider);
    if (playa && !_flame.isAnimating) {
      _flame.repeat(reverse: true);
    } else if (!playa && _flame.isAnimating) {
      _flame.stop();
      _flame.value = 0;
    }

    final label = playa
        ? 'Playa neon on — long press to turn off'
        : widget.isLight
            ? 'Switch to dark appearance — long press for Playa neon'
            : 'Switch to light appearance — long press for Playa neon';

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.medium();
          ref.read(visualThemeProvider.notifier).toggle();
        },
        onLongPress: () {
          AppHaptics.heavy();
          ref.read(playaModeProvider.notifier).toggle();
        },
        child: PlayaChromeFrame(
          size: 44,
          seed: 99,
          enabled: playa,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedBuilder(
                animation: _flame,
                builder: (context, _) {
                  if (playa) {
                    final pulse = lerpDouble(0.55, 1, _flame.value)!;
                    return _FlameIcon(pulse: pulse);
                  }
                  return Icon(
                    widget.isLight
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 22,
                    color: widget.ink,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlameIcon extends StatelessWidget {
  const _FlameIcon({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          size: 24 + pulse * 2,
          color: PlayaColors.ember.withAlpha((180 * pulse).round()),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              PlayaColors.ember,
              Color.lerp(PlayaColors.flame, PlayaColors.gold, pulse)!,
              PlayaColors.gold,
            ],
          ).createShader(bounds),
          child: Icon(
            Icons.local_fire_department_rounded,
            size: 22 + pulse,
            color: Colors.white,
          ),
        ),
        if (pulse > 0.7)
          Icon(
            Icons.local_fire_department_rounded,
            size: 26,
            color: PlayaColors.magenta.withAlpha((40 * pulse).round()),
          ),
      ],
    );
  }
}
