import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swipess wordmark.
///
/// Welcome/auth branding must never depend on a padded raster image. The white
/// and transparent variants are rendered directly by Flutter so they float on
/// the page with no square, plate, bitmap canvas or background artifact.
class SwipessLogo extends StatelessWidget {
  const SwipessLogo({
    super.key,
    this.height,
    this.width,
    this.variant = SwipessLogoVariant.transparent,
    this.color,
  });

  final double? height;
  final double? width;
  final SwipessLogoVariant variant;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (variant == SwipessLogoVariant.hero) {
      return _FloatingWordmark(
        width: width,
        height: height,
        color: color ?? AppTheme.mexicanRed,
        glow: true,
      );
    }

    // These two variants are used by welcome/auth/splash surfaces. Never use a
    // raster asset here: the old PNGs contain padded canvases which can appear
    // as a visible square against the black page.
    if (variant == SwipessLogoVariant.white ||
        variant == SwipessLogoVariant.transparent) {
      return _FloatingWordmark(
        width: width,
        height: height,
        color: color ?? Colors.white,
        glow: false,
      );
    }

    // The outline asset remains available for places that explicitly request
    // the outline treatment; it is not used by the welcome/auth hero branding.
    return Image.asset(
      AppAssets.wordmarkOutline,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _FloatingWordmark(
        width: width,
        height: height,
        color: color ?? Colors.white,
        glow: false,
      ),
    );
  }
}

class _FloatingWordmark extends StatelessWidget {
  const _FloatingWordmark({
    this.width,
    this.height,
    required this.color,
    required this.glow,
  });

  final double? width;
  final double? height;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    final boxWidth = width ?? (screen * 0.78).clamp(240.0, 720.0);
    final fontSize = height ?? (boxWidth * 0.25).clamp(58.0, 150.0);

    return SizedBox(
      width: boxWidth,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          'SWIPESS',
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -4,
            height: 0.88,
            shadows: glow
                ? [
                    Shadow(
                      color: color.withValues(alpha: 0.38),
                      blurRadius: 28,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : const [],
          ),
        ),
      ),
    );
  }
}

enum SwipessLogoVariant { transparent, outline, white, hero }
