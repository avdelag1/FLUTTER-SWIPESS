import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

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

class _GlowSearchBarState extends State<GlowSearchBar> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      // Wait for 90% of the 10 seconds, then sweep quickly in the last 10%
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
                      color: const Color(0xFF60A5FA).withAlpha(90),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 0),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(150),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  gradient: SweepGradient(
                    center: FractionalOffset.center,
                    transform: GradientRotation(_shimmerAnimation.value * 2 * math.pi),
                    colors: [
                      const Color(0xFF60A5FA).withAlpha(150),
                      const Color(0xFF60A5FA).withAlpha(150),
                      Colors.white.withAlpha(255), // bright moving light
                      const Color(0xFF60A5FA).withAlpha(150),
                      const Color(0xFF60A5FA).withAlpha(150),
                    ],
                    stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(2.5), // The width of the animated border
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black, // Dark fill inside the border
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: child,
                ),
              );
            },
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF60A5FA),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IgnorePointer(
                      ignoring: widget.onTap != null && widget.onChanged == null,
                      child: TextField(
                        controller: widget.controller,
                        enabled: widget.onTap == null || widget.onChanged != null,
                        onChanged: widget.onChanged,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.5),
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
        const SizedBox(height: 8),
        // AI Warning text left aligned
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF60A5FA),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Powered by Gemini',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'AI may make mistakes.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withAlpha(120),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Filters Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildOuterPill(Icons.location_on_rounded, 'Tulum'),
            _buildOuterPill(Icons.calendar_month_rounded, 'Dates'),
            _buildOuterPill(Icons.person_rounded, '1 guest'),
          ],
        ),
      ],
    );
  }

  Widget _buildOuterPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
