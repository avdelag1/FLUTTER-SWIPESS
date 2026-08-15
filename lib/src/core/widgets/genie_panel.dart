import 'package:flutter/material.dart';

/// Cap `genieMotion` — spring open from the bottom, shrink-to-dock on close.
class GeniePanel extends StatefulWidget {
  const GeniePanel({
    super.key,
    required this.builder,
    required this.onDismissed,
    this.barrierColor = const Color(0xCC000000),
  });

  final Widget Function(BuildContext context, VoidCallback dismiss) builder;
  final VoidCallback onDismissed;
  final Color barrierColor;

  @override
  State<GeniePanel> createState() => _GeniePanelState();
}

class _GeniePanelState extends State<GeniePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.18, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Cubic(0.22, 1.2, 0.36, 1),
        reverseCurve: const Cubic(0.4, 0, 0.7, 0.2),
      ),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.42), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Cubic(0.22, 1.1, 0.36, 1),
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> dismiss() async {
    if (_ctrl.status == AnimationStatus.dismissed) {
      widget.onDismissed();
      return;
    }
    await _ctrl.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: dismiss,
              child: ColoredBox(
                color: widget.barrierColor.withAlpha(
                  (204 * _fade.value).round().clamp(0, 255),
                ),
              ),
            ),
            FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scale: _scale.value,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: widget.builder(context, dismiss),
    );
  }
}
