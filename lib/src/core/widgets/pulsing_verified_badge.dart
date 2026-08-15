import 'package:flutter/material.dart';

/// Cap VapValidate success mark — pulsing green ring + check.
class PulsingVerifiedBadge extends StatefulWidget {
  const PulsingVerifiedBadge({super.key, this.valid = true, this.size = 80});

  final bool valid;
  final double size;

  @override
  State<PulsingVerifiedBadge> createState() => _PulsingVerifiedBadgeState();
}

class _PulsingVerifiedBadgeState extends State<PulsingVerifiedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Cap VAP success is mostly static — one heartbeat pulse, then hold.
    _pulse.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulse.reverse();
      }
    });
    _pulse.forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.valid
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = 0.55 + (_pulse.value * 0.45);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(28),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha((90 * t).round()),
                blurRadius: 18 + (12 * _pulse.value),
                spreadRadius: 4 + (6 * _pulse.value),
              ),
            ],
            border: Border.all(color: color.withAlpha(40), width: 8),
          ),
          child: child,
        );
      },
      child: Icon(
        widget.valid ? Icons.check_circle_rounded : Icons.verified_user_rounded,
        color: color,
        size: widget.size * 0.5,
      ),
    );
  }
}
