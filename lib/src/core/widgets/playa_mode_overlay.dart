import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
      clipBehavior: Clip.none,
      children: [
        child,
        if (enabled)
          const Positioned.fill(
            child: PlayaLiveLightsOverlay(),
          ),
      ],
    );
  }
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

/// Fast random neon streaks — game-border energy, no shade wash.
class PlayaLiveLightsOverlay extends StatefulWidget {
  const PlayaLiveLightsOverlay({super.key});

  @override
  State<PlayaLiveLightsOverlay> createState() => _PlayaLiveLightsOverlayState();
}

class _PlayaLiveLightsOverlayState extends State<PlayaLiveLightsOverlay>
    with SingleTickerProviderStateMixin {
  final _rng = math.Random();
  final List<_LightParticle> _particles = [];
  late final Ticker _ticker;
  Duration? _lastTick;
  double _phase = 0;
  Size? _size;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final size = _size;
    if (size == null || size.isEmpty) return;

    final last = _lastTick ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    _phase = elapsed.inMilliseconds / 1000.0;

    if (dt > 0 && dt < 0.08) {
      _step(size, dt);
    }
    if (mounted) setState(() {});
  }

  void _seedParticles(Size size) {
    if (_particles.isNotEmpty) return;
    for (var i = 0; i < 28; i++) {
      final edge = _rng.nextInt(4);
      final pos = switch (edge) {
        0 => Offset(_rng.nextDouble() * size.width, 0),
        1 => Offset(size.width, _rng.nextDouble() * size.height),
        2 => Offset(_rng.nextDouble() * size.width, size.height),
        _ => Offset(0, _rng.nextDouble() * size.height),
      };
      final speed = 320 + _rng.nextDouble() * 480;
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
      if (p.trail.length > 10) p.trail.removeLast();

      if (p.pos.dx < 0 || p.pos.dx > size.width) {
        p.vel = Offset(-p.vel.dx, p.vel.dy);
        p.pos = Offset(p.pos.dx.clamp(0, size.width), p.pos.dy);
      }
      if (p.pos.dy < 0 || p.pos.dy > size.height) {
        p.vel = Offset(p.vel.dx, -p.vel.dy);
        p.pos = Offset(p.pos.dx, p.pos.dy.clamp(0, size.height));
      }

      if (_rng.nextDouble() < 0.04) {
        final nudge = (_rng.nextDouble() - 0.5) * 600;
        p.vel += Offset(nudge, (_rng.nextDouble() - 0.5) * 600);
        const max = 780.0;
        if (p.vel.distance > max) p.vel = p.vel / p.vel.distance * max;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size.width > 0 &&
              size.height > 0 &&
              size.width.isFinite &&
              size.height.isFinite) {
            _size = size;
            _seedParticles(size);
          }
          return CustomPaint(
            size: size,
            painter: _ArcadeLightsPainter(
              particles: _particles,
              phase: _phase,
            ),
          );
        },
      ),
    );
  }
}

class _ArcadeLightsPainter extends CustomPainter {
  _ArcadeLightsPainter({
    required this.particles,
    required this.phase,
  });

  final List<_LightParticle> particles;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _drawScreenFrame(canvas, size, phase);
    for (final p in particles) {
      for (var i = 0; i < p.trail.length; i++) {
        final alpha = ((1 - i / p.trail.length) * 220).round();
        final trailPaint = Paint()
          ..color = p.color.withAlpha(alpha)
          ..strokeWidth = 4.5 - i * 0.3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        if (i + 1 < p.trail.length) {
          canvas.drawLine(p.trail[i], p.trail[i + 1], trailPaint);
        }
      }
      final core = Paint()
        ..color = p.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(p.pos, 6, core);
      final halo = Paint()
        ..color = p.color.withAlpha(120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(p.pos, 16, halo);
    }
  }

  void _drawScreenFrame(Canvas canvas, Size size, double t) {
    const inset = 4.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final perimeter = (rect.width + rect.height) * 2;

    for (var runner = 0; runner < 3; runner++) {
      final travel = ((t * (2.8 + runner * 0.7) * perimeter) + runner * 90) %
          perimeter;
      final point = _pointOnRectPerimeter(rect, travel);
      final color = PlayaColors.neon[runner % PlayaColors.neon.length];
      final runnerPaint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(point, 10, runnerPaint);
      canvas.drawCircle(point, 22, runnerPaint..color = color.withAlpha(70));
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..color = PlayaColors.ember.withAlpha(160)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      border,
    );

    const cornerLen = 42.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    final cornerColors = [
      PlayaColors.lime,
      PlayaColors.magenta,
      PlayaColors.cyan,
      PlayaColors.gold,
    ];
    for (var i = 0; i < corners.length; i++) {
      final c = corners[i];
      final flicker = math.sin((t * 10 + i) * math.pi) * 0.5 + 0.5;
      final paint = Paint()
        ..color = cornerColors[i].withAlpha((140 + flicker * 115).round())
        ..strokeWidth = 3.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
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
      duration: const Duration(milliseconds: 700),
    )..repeat();
    _scheduleShapeShift();
  }

  void _scheduleShapeShift() {
    Future<void>.delayed(
      Duration(milliseconds: 1800 + (widget.seed % 5) * 300),
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
              clipper: _PlayaShapeClipper(shape: _shape, inset: 3),
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
    final inset = 2.0;
    final rect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final color = PlayaColors.neon[(seed + (phase * 8).floor()) % PlayaColors.neon.length];

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = color.withAlpha(200)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    _strokeShape(canvas, rect, size, border);

    final runnerPos = _pointOnShape(shape, rect, phase);
    final glow = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(runnerPos, 5.5, glow);
    canvas.drawCircle(runnerPos, 14, glow..color = color.withAlpha(90));

    final trailPaint = Paint()
      ..color = color.withAlpha(220)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final trailStart = _pointOnShape(shape, rect, (phase - 0.12).clamp(0.0, 1.0));
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
            if (i == 6) {
              return Offset(
                cx + math.cos(-math.pi / 2) * r,
                cy + math.sin(-math.pi / 2) * r,
              );
            }
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

void showPlayaModeSnackBar(BuildContext context, bool enabled) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      backgroundColor: enabled ? PlayaColors.ember : const Color(0xFF1A1A1A),
      content: Text(
        enabled ? 'PLAYA NEON ON — tap moon to turn off' : 'Playa neon off',
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    ),
  );
}

/// Moon/sun button — tap toggles playa neon, long-press toggles theme.
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
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _flame.dispose();
    super.dispose();
  }

  Future<void> _togglePlaya() async {
    AppHaptics.heavy();
    await ref.read(playaModeProvider.notifier).toggle();
    if (!mounted) return;
    showPlayaModeSnackBar(context, ref.read(playaModeProvider));
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
        ? 'Playa neon on — tap to turn off'
        : widget.isLight
            ? 'Tap for Playa neon — hold for dark mode'
            : 'Tap for Playa neon — hold for light mode';

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlaya,
        onLongPress: () {
          AppHaptics.medium();
          ref.read(visualThemeProvider.notifier).toggle();
        },
        child: PlayaChromeFrame(
          size: 44,
          seed: 99,
          enabled: playa,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: playa
                    ? AnimatedBuilder(
                        key: const ValueKey('flame'),
                        animation: _flame,
                        builder: (context, _) {
                          final pulse = lerpDouble(0.6, 1, _flame.value)!;
                          return _FlameIcon(pulse: pulse);
                        },
                      )
                    : Icon(
                        key: const ValueKey('theme'),
                        widget.isLight
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 22,
                        color: widget.ink,
                      ),
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
          size: 28 + pulse * 3,
          color: PlayaColors.ember.withAlpha((220 * pulse).round()),
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
            size: 26 + pulse * 2,
            color: Colors.white,
          ),
        ),
        Icon(
          Icons.local_fire_department_rounded,
          size: 32,
          color: PlayaColors.magenta.withAlpha((70 * pulse).round()),
        ),
      ],
    );
  }
}
