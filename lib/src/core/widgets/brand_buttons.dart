import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandPrimaryButton extends StatelessWidget {
  const BrandPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.backgroundColor = AppTheme.brandPrimary,
    this.foregroundColor = Colors.white,
    this.ringColor,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? ringColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ringColor ?? backgroundColor.withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled
                ? () {
                    HapticFeedback.mediumImpact();
                    onPressed?.call();
                  }
                : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foregroundColor,
                          ),
                        )
                      else ...[
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: foregroundColor),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label.toUpperCase(),
                          style: AppTheme.buttonLabel.copyWith(color: foregroundColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandGhostButton extends StatelessWidget {
  const BrandGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x99FFFFFF), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x26FFFFFF), blurRadius: 20),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onPressed?.call();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.toUpperCase(),
                  style: AppTheme.buttonLabel.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xE6FFFFFF), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x33FFFFFF), blurRadius: 24, offset: Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    onPressed?.call();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconCircle extends StatelessWidget {
  const GlassIconCircle({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x40FFFFFF)),
        ),
        child: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          icon: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
        ),
      ),
    );
  }
}
