import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowSearchBar extends StatelessWidget {
  const GlowSearchBar({
    super.key,
    this.hint = 'Search Swipess',
    this.onTap,
    this.controller,
  });

  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: AppTheme.glassPill(glowing: true),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: IgnorePointer(
                  ignoring: onTap != null,
                  child: TextField(
                    controller: controller,
                    enabled: onTap == null,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
