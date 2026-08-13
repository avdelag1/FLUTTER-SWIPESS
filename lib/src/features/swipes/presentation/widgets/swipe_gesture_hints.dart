import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `GestureHints` — first-run left/right swipe affordances.
///
/// Fades in after ~700ms, hides when [hidden] (drag / hold-zoom).
class SwipeGestureHints extends StatefulWidget {
  const SwipeGestureHints({super.key, this.hidden = false});

  final bool hidden;

  @override
  State<SwipeGestureHints> createState() => _SwipeGestureHintsState();
}

class _SwipeGestureHintsState extends State<SwipeGestureHints>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hide = widget.hidden || !_ready;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: hide ? 0 : 1,
        duration: Duration(milliseconds: hide ? 150 : 500),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            // Cap: ±6px over 2s, then 1s rest.
            final t = _pulse.value;
            final active = t < (2 / 3);
            final wave = active
                ? math.sin((t / (2 / 3)) * math.pi * 2)
                : 0.0;
            final dx = 6 * wave;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: const Alignment(0, 0.35),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Transform.translate(
                      offset: Offset(-dx, 0),
                      child: const _HintChip(
                        icon: Icons.arrow_back_rounded,
                        label: 'Pass',
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(dx, 0),
                      child: const _HintChip(
                        icon: Icons.arrow_forward_rounded,
                        label: 'Like',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(64),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withAlpha(153),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}
