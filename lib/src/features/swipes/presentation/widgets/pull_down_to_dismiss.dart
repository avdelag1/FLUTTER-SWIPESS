import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Cap `usePullDownToDismiss` — top-edge pull only.
///
/// The recognizer itself rejects pointers that do not begin inside the physical
/// top edge. This is intentionally stronger than checking the position inside
/// an `onVerticalDragStart` callback: a normal full-screen vertical recognizer
/// still joins Flutter's gesture arena and can steal the listing deck's Reels
/// gesture before that callback ever decides to ignore it.
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
  static const _edgeExtent = 56.0;

  double _y = 0;
  bool _dragging = false;
  bool _dismissing = false;
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

  void _onDragStart(DragStartDetails details) {
    if (_dismissing) return;
    _anim?.stop();
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging || _dismissing) return;
    setState(() => _y = math.max(0, _y + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging || _dismissing) {
      _dragging = false;
      return;
    }
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    if (_y >= widget.threshold || velocity > 1100) {
      _dismissing = true;
      AppHaptics.medium();
      final height = MediaQuery.sizeOf(context).height;
      _runTo(height * 0.95, onDone: widget.onDismiss);
    } else {
      _runTo(0);
    }
  }

  void _onDragCancel() {
    if (!_dragging || _dismissing) return;
    _dragging = false;
    if (_y != 0) _runTo(0);
  }

  Widget _gestureHost(Widget child) {
    return RawGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      gestures: <Type, GestureRecognizerFactory>{
        _TopEdgeVerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _TopEdgeVerticalDragGestureRecognizer
            >(
              () => _TopEdgeVerticalDragGestureRecognizer(
                edgeExtent: _edgeExtent,
              ),
              (recognizer) {
                recognizer
                  ..onStart = _onDragStart
                  ..onUpdate = _onDragUpdate
                  ..onEnd = _onDragEnd
                  ..onCancel = _onDragCancel;
              },
            ),
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_y == 0) return _gestureHost(widget.child);

    final t = (_y / 220).clamp(0.0, 1.0);
    final scale = 1 - (0.22 * Curves.easeOut.transform(t));
    final opacity = (1 - 0.55 * Curves.easeOut.transform(t)).clamp(0.35, 1.0);

    return _gestureHost(
      Transform.translate(
        offset: Offset(0, _y),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Opacity(opacity: opacity, child: widget.child),
        ),
      ),
    );
  }
}

/// A vertical drag recognizer that only joins the gesture arena when the
/// pointer starts inside [edgeExtent]. Everywhere else the listing deck's own
/// pan recognizer is the only contender, so vertical Reels paging stays smooth.
class _TopEdgeVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  _TopEdgeVerticalDragGestureRecognizer({required this.edgeExtent});

  final double edgeExtent;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (event.position.dy > edgeExtent) return false;
    return super.isPointerAllowed(event);
  }
}
