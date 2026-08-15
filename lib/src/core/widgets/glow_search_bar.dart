import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowSearchBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(200),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF60A5FA).withAlpha(200), width: 2.5),
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
            ),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: const Color(0xFF60A5FA),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IgnorePointer(
                      ignoring: onTap != null && onChanged == null,
                      child: TextField(
                        controller: controller,
                        enabled: onTap == null || onChanged != null,
                        onChanged: onChanged,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: hint,
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
        const SizedBox(height: 16),
        // AI Warning text
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: const Color(0xFF60A5FA),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Powered by Gemini',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withAlpha(200),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'AI may make mistakes. Your information is secure.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withAlpha(120),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
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
