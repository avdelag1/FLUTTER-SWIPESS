import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Instagram-story-style pull-down dismissal for full-screen experiences.
///
/// Normal pointer tracking is kept as a fallback, but the top-center handle
/// owns a dedicated vertical drag recognizer. That makes dismissal reliable on
/// Flutter web even when an HTML-backed video surface or a scrollable would
/// otherwise win the gesture arena.
class PullDownToDashboard extends StatefulWidget {
  const PullDownToDashboard({
    super.key,
    required this.child,
    required this.onDismiss,
    this.dismissDistance = 72,
    this.maxDrag = 360,
    this.showHandle = true,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final double dismissDistance;
  final double maxDrag;
  final bool showHandle;

  @override
  State<PullDownToDashboard> createState() => _PullDownToDashboardState();
}

class _PullDownToDashboardState extends State<PullDownToDashboard> {
  double _scrollPixels = 0;
  double _dragY = 0;
  Offset? _pointerStart;
  bool _armed = false;
  bool _tracking = false;
  bool _closing = false;
  bool _handleTracking = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0) {
      _scrollPixels = notification.metrics.pixels;
    }
    return false;
  }

  bool get _canPull => !_closing && _scrollPixels <= 1;

  void _setDrag(double value) {
    final next = value.clamp(0.0, widget.maxDrag).toDouble();
    if (!mounted || next == _dragY) return;
    setState(() {
      _tracking = next > 0;
      _dragY = next;
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_closing || _handleTracking) return;
    _pointerStart = event.position;
    _armed = _canPull;
    _tracking = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_handleTracking || _closing || !_armed || _pointerStart == null) return;
    final delta = event.position - _pointerStart!;

    // Keep horizontal gallery swipes and upward page scrolling untouched.
    if (delta.dy <= 0 || delta.dx.abs() > delta.dy.abs() * .9) return;
    if (!_tracking && delta.dy < 8) return;

    _setDrag(delta.dy);
  }

  void _onPointerUp(PointerEvent event) {
    if (_handleTracking || _closing) return;
    _pointerStart = null;
    _finishDrag();
  }

  void _onHandleDragStart(DragStartDetails details) {
    if (!_canPull) return;
    _pointerStart = null;
    _armed = true;
    _handleTracking = true;
    if (mounted) {
      setState(() {
        _tracking = true;
        _dragY = 0;
      });
    }
  }

  void _onHandleDragUpdate(DragUpdateDetails details) {
    if (!_handleTracking || !_armed || _closing) return;
    final dy = details.primaryDelta ?? 0;
    _setDrag(_dragY + dy);
  }

  void _onHandleDragEnd(DragEndDetails details) {
    if (!_handleTracking) return;
    final velocity = details.primaryVelocity ?? 0;
    _handleTracking = false;
    _finishDrag(velocity: velocity);
  }

  void _onHandleDragCancel() {
    if (!_handleTracking) return;
    _handleTracking = false;
    _finishDrag();
  }

  void _finishDrag({double velocity = 0}) {
    if (_closing) return;
    _armed = false;

    if (_tracking && (_dragY >= widget.dismissDistance || velocity > 650)) {
      unawaited(_dismiss());
      return;
    }

    if (_dragY != 0 || _tracking) {
      setState(() {
        _tracking = false;
        _dragY = 0;
      });
    }
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    AppHaptics.medium();

    final height = MediaQuery.sizeOf(context).height;
    setState(() {
      _tracking = false;
      _dragY = height;
    });

    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final topPadding = MediaQuery.paddingOf(context).top;
    final progress = (_dragY / (height * .55)).clamp(0.0, 1.0);
    final scale = 1 - (progress * .035);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: _tracking
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transformAlignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..translate(0.0, _dragY)
                ..scale(scale, scale),
              child: widget.child,
            ),

            // Dedicated drag surface above HTML video/platform views. Keeping
            // it away from the left/right edges preserves back/share controls.
            Positioned(
              top: 0,
              left: 72,
              right: 72,
              height: topPadding + 78,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: _onHandleDragStart,
                onVerticalDragUpdate: _onHandleDragUpdate,
                onVerticalDragEnd: _onHandleDragEnd,
                onVerticalDragCancel: _onHandleDragCancel,
                child: const SizedBox.expand(),
              ),
            ),

            if (widget.showHandle)
              Positioned(
                top: topPadding + 7,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _dragY > 0 ? 1 : .82,
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(185),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x77000000),
                              blurRadius: 9,
                            ),
                          ],
                        ),
                      ),
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
