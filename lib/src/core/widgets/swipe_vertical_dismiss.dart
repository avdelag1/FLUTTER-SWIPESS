import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Swipe up or down to dismiss a presentation surface (Virtual ID, sheets, etc.).
///
/// When [scrollController] is provided, dismiss only engages at the scroll
/// top (pull down) or bottom (pull up) so inner lists keep scrolling normally.
class SwipeVerticalDismiss extends StatefulWidget {
  const SwipeVerticalDismiss({
    super.key,
    required this.child,
    required this.onDismiss,
    this.scrollController,
    this.threshold = 72,
    this.velocityThreshold = 900,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final ScrollController? scrollController;
  final double threshold;
  final double velocityThreshold;

  @override
  State<SwipeVerticalDismiss> createState() => _SwipeVerticalDismissState();
}

class _SwipeVerticalDismissState extends State<SwipeVerticalDismiss>
    with SingleTickerProviderStateMixin {
  static const _axisLock = 10.0;

  double _offset = 0;
  bool _dismissing = false;
  bool _dismissDrag = false;
  int? _activePointer;
  Offset? _pointerStart;
  VelocityTracker? _velocityTracker;
  AnimationController? _anim;

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  bool _atTop() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return true;
    return controller.offset <= controller.position.minScrollExtent + 0.5;
  }

  bool _atBottom() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return true;
    final position = controller.position;
    return position.maxScrollExtent <= 0.5 ||
        position.pixels >= position.maxScrollExtent - 0.5;
  }

  bool _canDismissDrag(double dy) {
    if (dy > 0) return _atTop();
    if (dy < 0) return _atBottom();
    return false;
  }

  void _runSpringTo(
    double target, {
    double velocity = 0,
    VoidCallback? onDone,
  }) {
    _anim?.dispose();
    final controller = AnimationController.unbounded(vsync: this);
    final simulation = SpringSimulation(
      const SpringDescription(mass: 0.72, stiffness: 420, damping: 30),
      _offset,
      target,
      velocity,
    );
    void tick() {
      if (!mounted || !controller.isAnimating) return;
      setState(() => _offset = controller.value);
    }

    controller.addListener(tick);
    _anim = controller;
    controller.animateWith(simulation).whenComplete(() {
      controller.removeListener(tick);
      if (!mounted) return;
      onDone?.call();
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_dismissing) return;
    _anim?.stop();
    _activePointer = event.pointer;
    _pointerStart = event.position;
    _dismissDrag = false;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dismissing || _activePointer != event.pointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final start = _pointerStart;
    if (start == null) return;
    final delta = event.position - start;

    if (!_dismissDrag) {
      if (delta.distance < _axisLock) return;
      if (delta.dy.abs() < delta.dx.abs()) {
        _activePointer = null;
        return;
      }
      if (!_canDismissDrag(delta.dy)) return;
      _dismissDrag = true;
      AppHaptics.selection();
    }

    setState(() => _offset = delta.dy);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _finishDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _finishDrag(cancelled: true);
  }

  void _finishDrag({bool cancelled = false}) {
    _activePointer = null;
    _pointerStart = null;
    if (!_dismissDrag || _dismissing) {
      _dismissDrag = false;
      if (_offset != 0 && !cancelled) _runSpringTo(0);
      return;
    }
    _dismissDrag = false;

    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final shouldDismiss = _offset.abs() >= widget.threshold ||
        velocity.abs() > widget.velocityThreshold;
    if (shouldDismiss) {
      _dismissing = true;
      AppHaptics.medium();
      final height = MediaQuery.sizeOf(context).height;
      final direction = velocity != 0
          ? (velocity < 0 ? -1.0 : 1.0)
          : (_offset < 0 ? -1.0 : 1.0);
      _runSpringTo(
        direction * height * 0.95,
        velocity: velocity,
        onDone: widget.onDismiss,
      );
      return;
    }
    _runSpringTo(0, velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    final t = (_offset.abs() / 220).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    final scale = 1 - (0.08 * eased);
    final opacity = (1 - 0.35 * eased).clamp(0.55, 1.0);

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Transform.translate(
        offset: Offset(0, _offset),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Opacity(opacity: opacity, child: widget.child),
        ),
      ),
    );
  }
}
