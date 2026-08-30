import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Game-style elastic pull-to-refresh with perspective bend and a hard reload.
class ElasticPullRefresh extends StatefulWidget {
  const ElasticPullRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 108,
    this.maxPull = 220,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final double triggerDistance;
  final double maxPull;

  @override
  State<ElasticPullRefresh> createState() => _ElasticPullRefreshState();
}

class _ElasticPullRefreshState extends State<ElasticPullRefresh>
    with SingleTickerProviderStateMixin {
  static const _hapticBands = [0.35, 0.65, 1.0];

  double _scrollPixels = 0;
  double _pull = 0;
  bool _armed = false;
  bool _tracking = false;
  bool _refreshing = false;
  int _hapticMask = 0;
  Offset? _pointerStart;
  AnimationController? _anim;

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  bool get _canPull => !_refreshing && _scrollPixels <= 0.5;

  double get _progress =>
      (_pull / widget.triggerDistance).clamp(0.0, 1.35);

  bool get _ready => _progress >= 1.0;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0) {
      _scrollPixels = notification.metrics.pixels;
    }
    return false;
  }

  void _setPull(double value) {
    final next = value.clamp(0.0, widget.maxPull).toDouble();
    if (!mounted || next == _pull) return;
    setState(() {
      _tracking = next > 0;
      _pull = next;
    });
    _maybePulseHaptics();
  }

  void _maybePulseHaptics() {
    for (var i = 0; i < _hapticBands.length; i++) {
      final bit = 1 << i;
      if (_progress >= _hapticBands[i] && (_hapticMask & bit) == 0) {
        _hapticMask |= bit;
        unawaited(AppHaptics.selection());
      }
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_refreshing) return;
    _pointerStart = event.position;
    _armed = _canPull;
    _hapticMask = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_refreshing || !_armed || _pointerStart == null) return;
    final delta = event.position - _pointerStart!;
    if (delta.dy <= 0 || delta.dx.abs() > delta.dy.abs() * 0.92) return;
    if (!_tracking && delta.dy < 6) return;
    _setPull(delta.dy);
  }

  void _onPointerUp(PointerEvent event) {
    if (_refreshing) return;
    _pointerStart = null;
    _armed = false;
    unawaited(_finishPull());
  }

  Future<void> _finishPull({double velocity = 0}) async {
    if (_refreshing) return;
    if (_tracking && (_ready || velocity > 900)) {
      await _runRefresh();
      return;
    }
    await _springTo(0, velocity: velocity);
    if (mounted) {
      setState(() {
        _tracking = false;
        _pull = 0;
        _hapticMask = 0;
      });
    }
  }

  Future<void> _springTo(double target, {double velocity = 0}) async {
    _anim?.dispose();
    final controller = AnimationController.unbounded(vsync: this);
    final simulation = SpringSimulation(
      const SpringDescription(mass: 0.78, stiffness: 390, damping: 28),
      _pull,
      target,
      velocity,
    );
    void tick() {
      if (!mounted || !controller.isAnimating) return;
      setState(() => _pull = controller.value);
    }

    controller.addListener(tick);
    _anim = controller;
    await controller.animateWith(simulation);
    controller.removeListener(tick);
  }

  Future<void> _runRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    AppHaptics.heavy();
    await _springTo(widget.triggerDistance * 0.82);
    try {
      await widget.onRefresh();
    } catch (_) {}
    if (!mounted) return;
    await _springTo(0);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _tracking = false;
      _pull = 0;
      _hapticMask = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final tilt = progress.clamp(0.0, 1.0) * 0.22;
    final stretch = 1 + (progress.clamp(0.0, 1.0) * 0.018);
    final sink = _pull * 0.42;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..translateByDouble(0, sink, 0, 1)
                ..rotateX(tilt)
                ..scaleByDouble(stretch, stretch, 1, 1),
              child: widget.child,
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _pull > 4 || _refreshing ? 1 : 0,
                  child: _RefreshOrb(
                    progress: progress,
                    ready: _ready || _refreshing,
                    spinning: _refreshing,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshOrb extends StatefulWidget {
  const _RefreshOrb({
    required this.progress,
    required this.ready,
    required this.spinning,
  });

  final double progress;
  final bool ready;
  final bool spinning;

  @override
  State<_RefreshOrb> createState() => _RefreshOrbState();
}

class _RefreshOrbState extends State<_RefreshOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _RefreshOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.spinning) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final scale = 0.72 + (progress.clamp(0.0, 1.0) * 0.42);
    final label = widget.ready
        ? 'RELEASE TO RELOAD SWIPESS'
        : 'PULL TO RELOAD SWIPESS';

    return Column(
      children: [
        Transform.scale(
          scale: scale,
          child: RotationTransition(
            turns: widget.spinning
                ? _spin
                : AlwaysStoppedAnimation(progress * 0.12),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: widget.ready
                      ? const [Color(0xFFFF7A45), Color(0xFFFF3040)]
                      : const [Color(0xFF7C3AED), Color(0xFF2563EB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (widget.ready
                            ? const Color(0xFFFF3040)
                            : const Color(0xFF2563EB))
                        .withAlpha((120 + progress * 80).round().clamp(0, 255)),
                    blurRadius: 24 + progress * 18,
                    spreadRadius: progress * 2,
                  ),
                ],
              ),
              child: widget.spinning
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      widget.ready
                          ? Icons.bolt_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withAlpha((180 + progress * 60).round()),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}
