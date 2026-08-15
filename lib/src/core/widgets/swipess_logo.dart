import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor wordmark.
///
/// [SwipessLogoVariant.hero] paints a huge italic text plate — the PNG
/// assets sit on a black padded canvas so they never read as big enough
/// on welcome / auth. Other variants still use the brand PNGs.
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
      return _HeroWordmark(
        width: width,
        height: height,
        color: color ?? AppTheme.mexicanRed,
      );
    }

    final asset = switch (variant) {
      SwipessLogoVariant.transparent => AppAssets.logoTransparent,
      SwipessLogoVariant.outline => AppAssets.wordmarkOutline,
      SwipessLogoVariant.white => AppAssets.wordmarkWhite,
      SwipessLogoVariant.hero => AppAssets.logoTransparent,
    };

    return Image.asset(
      asset,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) {
        final px = height ?? ((width ?? 220) * 0.28);
        return Text(
          'SWIPESS',
          style: GoogleFonts.plusJakartaSans(
            color: color ?? Colors.white,
            fontSize: px.clamp(36.0, 88.0),
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
            shadows: const [
              Shadow(offset: Offset(2, 3), blurRadius: 0, color: Colors.black),
            ],
          ),
        );
      },
    );
  }
}

class _HeroWordmark extends StatelessWidget {
  const _HeroWordmark({this.width, this.height, required this.color});

  final double? width;
  final double? height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    final boxWidth = width ?? (screen * 0.94).clamp(280.0, 920.0);
    final fontSize = height ?? (boxWidth * 0.28).clamp(72.0, 168.0);

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
            shadows: [
              const Shadow(
                offset: Offset(4, 5),
                blurRadius: 0,
                color: Colors.black,
              ),
              Shadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: 36,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SwipessLogoVariant { transparent, outline, white, hero }
