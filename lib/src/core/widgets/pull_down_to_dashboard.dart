import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Instagram-story-style pull-down dismissal for full-screen experiences.
///
/// The gesture only arms while the descendant scrollable is already at its
/// top edge, so normal vertical reading/scrolling is not hijacked. Once armed,
/// the whole surface follows the pointer. A meaningful pull closes; a short
/// accidental pull springs back into place.
class PullDownToDashboard extends StatefulWidget {
  const PullDownToDashboard({
    super.key,
    required this.child,
    required this.onDismiss,
    this.dismissDistance = 96,
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

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0) {
      _scrollPixels = notification.metrics.pixels;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_closing) return;
    _pointerStart = event.position;
    _armed = _scrollPixels <= 1;
    _tracking = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_closing || !_armed || _pointerStart == null) return;
    final delta = event.position - _pointerStart!;

    // Upward movement remains normal page scrolling. Horizontal movement is
    // left to galleries/carousels instead of stealing the gesture.
    if (delta.dy <= 0 || delta.dx.abs() > delta.dy.abs() * .9) return;

    final next = delta.dy.clamp(0.0, widget.maxDrag).toDouble();
    if (!_tracking && next < 5) return;

    setState(() {
      _tracking = true;
      _dragY = next;
    });
  }

  void _onPointerUp(PointerEvent event) {
    if (_closing) return;
    _pointerStart = null;

    if (_tracking && _dragY >= widget.dismissDistance) {
      unawaited(_dismiss());
      return;
    }

    if (_dragY != 0 || _tracking) {
      setState(() {
        _tracking = false;
        _armed = false;
        _dragY = 0;
      });
    } else {
      _armed = false;
    }
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    AppHaptics.light();

    final height = MediaQuery.sizeOf(context).height;
    setState(() {
      _tracking = false;
      _dragY = height;
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final progress = (_dragY / (height * .55)).clamp(0.0, 1.0);
    final scale = 1 - (progress * .025);

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
            if (widget.showHandle)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 7,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _dragY > 0 ? 1 : .72,
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(155),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 8,
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
