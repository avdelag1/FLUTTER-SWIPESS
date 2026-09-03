import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Top-edge pull interaction used by immersive swipe surfaces.
///
/// Callers can keep the historical dismiss behavior with [onDismiss], or opt
/// into an in-place professional refresh with [onRefresh]. The recognizer only
/// joins Flutter's gesture arena when the pointer starts at the physical top
/// edge, so normal listing swipes stay native-feeling and uninterrupted.
class PullDownToDismiss extends StatefulWidget {
  const PullDownToDismiss({
    super.key,
    required this.child,
    this.onDismiss,
    this.onRefresh,
    this.threshold = 64,
  }) : assert(onDismiss != null || onRefresh != null);

  final Widget child;
  final VoidCallback? onDismiss;
  final Future<void> Function()? onRefresh;
  final double threshold;

  @override
  State<PullDownToDismiss> createState() => _PullDownToDismissState();
}

class _PullDownToDismissState extends State<PullDownToDismiss>
    with SingleTickerProviderStateMixin {
  static const _edgeExtent = 64.0;

  double _y = 0;
  bool _dragging = false;
  bool _dismissing = false;
  bool _refreshing = false;
  AnimationController? _anim;

  bool get _refreshMode => widget.onRefresh != null;

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  void _runTo(double target, {VoidCallback? onDone}) {
    _anim?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
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
    if (_dismissing || _refreshing) return;
    _anim?.stop();
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging || _dismissing || _refreshing) return;
    final resistance = _refreshMode
        ? (_y >= widget.threshold ? 0.28 : 0.72)
        : 1.0;
    setState(() => _y = math.max(0, _y + details.delta.dy * resistance));
  }

  Future<void> _finishRefresh() async {
    try {
      await widget.onRefresh?.call();
    } finally {
      if (!mounted) return;
      _runTo(
        0,
        onDone: () {
          if (!mounted) return;
          setState(() => _refreshing = false);
        },
      );
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging || _dismissing || _refreshing) {
      _dragging = false;
      return;
    }
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    final committed = _y >= widget.threshold || velocity > 1050;

    if (!committed) {
      _runTo(0);
      return;
    }

    if (_refreshMode) {
      AppHaptics.medium();
      setState(() => _refreshing = true);
      final hold = math.max(widget.threshold, 68.0);
      _runTo(hold, onDone: () => unawaited(_finishRefresh()));
      return;
    }

    _dismissing = true;
    AppHaptics.medium();
    final height = MediaQuery.sizeOf(context).height;
    _runTo(height * 0.95, onDone: widget.onDismiss);
  }

  void _onDragCancel() {
    if (!_dragging || _dismissing || _refreshing) return;
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
    if (_y == 0 && !_refreshing) return _gestureHost(widget.child);

    final t = (_y / widget.threshold).clamp(0.0, 1.0);
    final pull = Curves.easeOutCubic.transform(t);
    final scale = _refreshMode ? 1 - 0.018 * pull : 1 - 0.22 * pull;
    final opacity = _refreshMode ? 1.0 : (1 - 0.55 * pull).clamp(0.35, 1.0);
    final translation = _refreshMode ? _y * 0.58 : _y;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return _gestureHost(
      Stack(
        fit: StackFit.expand,
        children: [
          if (_refreshMode)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 10,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: (_y > 4 || _refreshing) ? 1 : 0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.white.withAlpha(248)
                            : const Color(0xEE181C23),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isLight ? 28 : 88),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: _refreshing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                              ),
                            )
                          : Transform.rotate(
                              angle: t * math.pi * 1.6,
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 19,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(0, translation),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: Opacity(opacity: opacity, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopEdgeVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  _TopEdgeVerticalDragGestureRecognizer({required this.edgeExtent});

  final double edgeExtent;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (event is PointerDownEvent && event.position.dy > edgeExtent) {
      return false;
    }
    return super.isPointerAllowed(event);
  }
}
