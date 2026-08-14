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
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: widget.child,
    );
  }
}
