import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_controls.dart';
import 'package:google_fonts/google_fonts.dart';

/// Backward-compatible name used across the app. The implementation now routes
/// through the canonical Swipess control system.
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
    return SwipessButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      accentColor: backgroundColor,
      foregroundColor: foregroundColor,
      outlineColor: ringColor,
      height: height,
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
    return SwipessButton(
      label: label,
      onPressed: onPressed,
      height: height,
      variant: SwipessButtonVariant.ghost,
      haptic: SwipessHaptic.light,
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
    return SwipessPressable(
      onTap: onPressed,
      enabled: onPressed != null,
      haptic: SwipessHaptic.medium,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
      child: Container(
        width: double.infinity,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
          border: Border.all(color: Colors.black.withAlpha(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 12),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                softWrap: false,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 1.2,
                ),
              ),
            ],
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
    return SwipessIconAction(
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: size <= 40 ? 18 : 20,
    );
  }
}
