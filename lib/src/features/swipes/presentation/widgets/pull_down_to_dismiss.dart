import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Cap `usePullDownToDismiss` — top-edge pull only.
///
/// Important for web: no [ImageFiltered]/BackdropFilter here — full-screen
/// blur filters have caused black/frozen frames in Safari & Chrome.
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
  double _y = 0;
  bool _dragging = false;
  bool _dismissing = false;
  bool _armed = false;
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

  void _onDragStart(DragStartDetails d) {
    if (_dismissing) return;
    // Cap: only physical top edge (~56px) can arm pull-dismiss.
    // Never steal gestures from the card body / side rail / bottom dock.
    _armed = d.globalPosition.dy <= 56;
    if (!_armed) return;
    _anim?.stop();
    _dragging = false;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_armed || _dismissing) return;
    // Require clear downward intent before activating (don't fight horiz swipe).
    if (!_dragging) {
      if (d.delta.dy > 2 && d.delta.dy.abs() > d.delta.dx.abs() * 1.4) {
        _dragging = true;
      } else if (d.delta.dx.abs() > d.delta.dy.abs()) {
        _armed = false;
        return;
      } else {
        return;
      }
    }
    setState(() => _y = math.max(0, _y + d.delta.dy));
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_armed || _dismissing) {
      _armed = false;
      _dragging = false;
      return;
    }
    _armed = false;
    _dragging = false;
    final v = d.primaryVelocity ?? 0;
    if (_y >= widget.threshold || v > 1100) {
      _dismissing = true;
      AppHaptics.medium();
      final h = MediaQuery.sizeOf(context).height;
      _runTo(h * 0.95, onDone: widget.onDismiss);
    } else {
      _runTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = (_y / 220).clamp(0.0, 1.0);
    final scale = 1 - (0.22 * Curves.easeOut.transform(t));
    final opacity = (1 - 0.55 * Curves.easeOut.transform(t)).clamp(0.35, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(0, _y),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: opacity,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
