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
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        final opacity = 0.45 + (0.4 * t);
        final scale = 1.0 + (0.04 * t);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: RadialGradient(
                          colors: widget.isLight
                              ? const [
                                  Color(0x8CFFFFFF),
                                  Color(0x2EFFFFFF),
                                  Color(0x00000000),
                                ]
                              : const [
                                  Color(0x24FFFFFF),
                                  Color(0x0DFFFFFF),
                                  Color(0x00000000),
                                ],
                          stops: const [0, 0.45, 0.72],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}
