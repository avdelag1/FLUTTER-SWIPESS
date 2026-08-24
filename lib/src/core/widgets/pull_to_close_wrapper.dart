import 'package:flutter/material.dart';

/// A wrapper widget that allows full-screen views to be dismissed by dragging down,
/// similar to Instagram Stories or Snapchat.
/// 
/// Note: To see the underlying screen during the drag, the route must be pushed
/// with `opaque: false`.
class PullToCloseWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onClose;
  final double dismissThreshold;
  final bool topEdgeOnly;

  const PullToCloseWrapper({
    super.key,
    required this.child,
    required this.onClose,
    this.dismissThreshold = 150.0,
    this.topEdgeOnly = false,
  });

  @override
  State<PullToCloseWrapper> createState() => _PullToCloseWrapperState();
}

class _PullToCloseWrapperState extends State<PullToCloseWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  bool _validDrag = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVerticalDragDown(DragDownDetails details) {
    if (widget.topEdgeOnly && details.globalPosition.dy > 150) {
      _validDrag = false;
    } else {
      _validDrag = true;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_validDrag) return;
    if (details.primaryDelta! > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset += details.primaryDelta!;
        if (_dragOffset < 0) _dragOffset = 0;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_validDrag) return;
    if (_dragOffset > widget.dismissThreshold ||
        (details.primaryVelocity ?? 0) > 1000) {
      widget.onClose();
    } else {
      // Snap back to 0
      final double startOffset = _dragOffset;
      _controller.forward(from: 0.0).addListener(() {
        setState(() {
          _dragOffset = startOffset * (1.0 - _controller.value);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;
    double radius = 0.0;
    double opacity = 1.0;

    if (_dragOffset > 0) {
      final progress = (_dragOffset / 400).clamp(0.0, 1.0);
      scale = 1.0 - (progress * 0.15); // Scale down to 85% max
      radius = progress * 40.0; // Round corners up to 40px
      opacity = 1.0 - progress;
    }

    return GestureDetector(
      onVerticalDragDown: _onVerticalDragDown,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Container(
        // Solid black background that fades as we pull down
        color: Colors.black.withAlpha((opacity * 255).toInt()),
        child: Transform.translate(
          offset: Offset(0, _dragOffset * 0.5), // Move down at half speed of finger
          child: Transform.scale(
            scale: scale,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
