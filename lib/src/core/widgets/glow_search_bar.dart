import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowSearchBar extends StatefulWidget {
  const GlowSearchBar({
    super.key,
    this.hint = 'Search Swipess',
    this.onTap,
    this.controller,
    this.onChanged,
  });

  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  State<GlowSearchBar> createState() => _GlowSearchBarState();
}

class _GlowSearchBarState extends State<GlowSearchBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: const Interval(0.9, 1.0, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final muted = ink.withAlpha(145);
    final surface = isLight ? const Color(0xFFF7F7FA) : const Color(0xFF08080B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF60A5FA).withAlpha(isLight ? 48 : 78),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(isLight ? 28 : 105),
                      blurRadius: 20,
                      offset: const Offset(0, 9),
                    ),
                  ],
                  gradient: SweepGradient(
                    center: FractionalOffset.center,
                    transform: GradientRotation(
                      _shimmerAnimation.value * 2 * math.pi,
                    ),
                    colors: [
                      const Color(0xFF60A5FA).withAlpha(145),
                      const Color(0xFF60A5FA).withAlpha(145),
                      Colors.white,
                      const Color(0xFF60A5FA).withAlpha(145),
                      const Color(0xFF60A5FA).withAlpha(145),
                    ],
                    stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: child,
                ),
              );
            },
            child: SizedBox(
              height: 54,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF60A5FA),
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: IgnorePointer(
                      ignoring: widget.onTap != null && widget.onChanged == null,
                      child: TextField(
                        controller: widget.controller,
                        enabled: widget.onTap == null || widget.onChanged != null,
                        onChanged: widget.onChanged,
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: ink.withAlpha(115),
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF60A5FA),
              size: 11,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Powered by Gemini · AI may make mistakes.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _outerPill(
                Icons.location_on_rounded,
                'Tulum',
                ink,
                isLight,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _outerPill(
                Icons.calendar_month_rounded,
                'Dates',
                ink,
                isLight,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _outerPill(
                Icons.person_rounded,
                '1 guest',
                ink,
                isLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _outerPill(
    IconData icon,
    String label,
    Color ink,
    bool isLight,
  ) {
    final border = Colors.white.withAlpha(isLight ? 125 : 72);
    final highlight = Colors.white.withAlpha(isLight ? 150 : 42);
    final lowlight = isLight
        ? Colors.white.withAlpha(120)
        : const Color(0xFF07070A).withAlpha(145);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isLight ? 24 : 100),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.white.withAlpha(isLight ? 32 : 12),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [highlight, lowlight],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border, width: 0.9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: ink.withAlpha(205), size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
