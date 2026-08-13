import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stadium CTA. [SwipessCtaTone.mexican] is the Rosa Mexicano fill
/// (`#E4007C` → `#FF4D00`) so it cannot collapse into Material 3 brown.
class SwipessCtaButton extends StatelessWidget {
  const SwipessCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = SwipessCtaTone.mexican,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SwipessCtaTone tone;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = switch (tone) {
      SwipessCtaTone.mexican => Colors.white,
      SwipessCtaTone.white => Colors.black,
      SwipessCtaTone.ghost => Colors.white,
    };

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: _decoration(tone, enabled),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: fg),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: fg,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(SwipessCtaTone tone, bool enabled) {
    switch (tone) {
      case SwipessCtaTone.mexican:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: enabled
                ? const [AppTheme.mexicanRed, AppTheme.brandPrimary]
                : const [Color(0xFF5A2438), Color(0xFF4A2A20)],
          ),
          border: Border.all(
            color: AppTheme.mexicanRed.withValues(alpha: 0.9),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.mexicanRed.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        );
      case SwipessCtaTone.white:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 2),
        );
      case SwipessCtaTone.ghost:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 2,
          ),
        );
    }
  }
}

enum SwipessCtaTone { mexican, white, ghost }
