import 'package:flutter/material.dart';

/// Cap `.qf-well-glow--dark` / `--light` — soft pulsing wash behind bento grid.
class QfWellGlow extends StatefulWidget {
  const QfWellGlow({
    super.key,
    required this.child,
    required this.isLight,
    this.padding = const EdgeInsets.all(6),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  final Widget child;
  final bool isLight;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  State<QfWellGlow> createState() => _QfWellGlowState();
}

class _QfWellGlowState extends State<QfWellGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wash = widget.isLight
        ? const Color(0xFFFFFFFF)
        : const Color(0xFFE8E8EE);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        // ~3–8% white/grey — breathes slowly, almost imperceptible.
        final alpha = widget.isLight
            ? (10 + (t * 12)).round()
            : (8 + (t * 10)).round();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: wash.withAlpha(alpha),
            borderRadius: widget.borderRadius,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}
