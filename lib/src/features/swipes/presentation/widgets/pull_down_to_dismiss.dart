import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Top-edge pull-to-dismiss that deliberately stays out of Flutter's gesture
/// arena. The swipe deck owns vertical/horizontal pan recognition; this wrapper
/// only observes raw pointer motion that begins in the tiny top edge, so it can
/// never steal Reels-style vertical paging from listing cards.
class PullDownToDismiss extends StatefulWidget {
  const PullDownToDismiss({
    super.key,
    required this.child,
    required this.onDismiss,
    this.threshold = 56,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final double threshold;

  @override
  State<PullDownToDismiss> createState() => _PullDownToDismissState();
}

class _PullDownToDismissState extends State<PullDownToDismiss>
    with SingleTickerProviderStateMixin {
  static const _edgeHeight = 56.0;

  double _y = 0;
  bool _dragging = false;
  bool _dismissing = false;
  bool _armed = false;
  int? _pointer;
  Offset? _origin;
  Offset? _lastPosition;
  DateTime? _lastMoveAt;
  double _velocityY = 0;
  AnimationController? _anim;

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  void _runTo(double target, {VoidCallback? onDone}) {
    _anim?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    final animation = Tween<double>(begin: _y, end: target).animate(
      CurvedAnimation(parent: controller, curve: const Cubic(0.22, 1, 0.36, 1)),
    );
    animation.addListener(() {
      if (!mounted) return;
      setState(() => _y = animation.value);
    });
    _anim = controller;
    controller.forward().whenComplete(() {
      if (!mounted) return;
      onDone?.call();
    });
  }

  void _resetPointer() {
    _armed = false;
    _dragging = false;
    _pointer = null;
    _origin = null;
    _lastPosition = null;
    _lastMoveAt = null;
    _velocityY = 0;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_dismissing || event.position.dy > _edgeHeight) return;
    _anim?.stop();
    _armed = true;
    _dragging = false;
    _pointer = event.pointer;
    _origin = event.position;
    _lastPosition = event.position;
    _lastMoveAt = DateTime.now();
    _velocityY = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_armed || _dismissing || event.pointer != _pointer) return;
    final origin = _origin;
    final previous = _lastPosition;
    if (origin == null || previous == null) return;

    final travel = event.position - origin;
    if (!_dragging) {
      if (travel.dy > 3 && travel.dy.abs() > travel.dx.abs() * 1.4) {
        _dragging = true;
        AppHaptics.light();
      } else if (travel.dx.abs() > 8 && travel.dx.abs() > travel.dy.abs()) {
        _resetPointer();
        return;
      } else {
        _lastPosition = event.position;
        _lastMoveAt = DateTime.now();
        return;
      }
    }

    final now = DateTime.now();
    final lastAt = _lastMoveAt;
    if (lastAt != null) {
      final micros = now.difference(lastAt).inMicroseconds;
      if (micros > 0) {
        _velocityY =
            (event.position.dy - previous.dy) * Duration.microsecondsPerSecond /
            micros;
      }
    }
    _lastPosition = event.position;
    _lastMoveAt = now;
    setState(() => _y = math.max(0, travel.dy));
  }

  void _finishPointer(int pointer) {
    if (!_armed || _dismissing || pointer != _pointer) {
      if (pointer == _pointer) _resetPointer();
      return;
    }

    final shouldDismiss =
        _dragging && (_y >= widget.threshold || _velocityY > 1100);
    _resetPointer();
    if (shouldDismiss) {
      _dismissing = true;
      AppHaptics.medium();
      final height = MediaQuery.sizeOf(context).height;
      _runTo(height * 0.95, onDone: widget.onDismiss);
    } else if (_y != 0) {
      _runTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (_y != 0) {
      final t = (_y / 220).clamp(0.0, 1.0);
      final eased = Curves.easeOut.transform(t);
      final scale = 1 - (0.22 * eased);
      final opacity = (1 - 0.55 * eased).clamp(0.35, 1.0);
      child = Transform.translate(
        offset: Offset(0, _y),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Opacity(opacity: opacity, child: child),
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (event) => _finishPointer(event.pointer),
      onPointerCancel: (event) => _finishPointer(event.pointer),
      child: child,
    );
  }
}
