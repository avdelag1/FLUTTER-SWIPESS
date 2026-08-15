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
              border: Border.all(color: const Color(0xFF60A5FA).withAlpha(128), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF60A5FA).withAlpha(40),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
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
                  _buildInnerPill(Icons.calendar_month_rounded, 'Dates'),
                  const SizedBox(width: 8),
                  _buildInnerPill(Icons.person_rounded, '1 guest'),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: const Color(0xFF60A5FA).withAlpha(180),
              size: 12,
            ),
            const SizedBox(width: 6),
            Text(
              'Powered by Swipess AI',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withAlpha(150),
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInnerPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
