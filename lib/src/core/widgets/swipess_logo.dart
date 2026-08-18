import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Canonical Swipess wordmark.
///
/// Always prefer the real transparent brand artwork. Welcome/auth must never
/// synthesize a replacement wordmark in Flutter because that can drift from
/// the approved logo. The transparent PNG contains the real floating logo with
/// no plate/background.
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
    final asset = switch (variant) {
      SwipessLogoVariant.outline => AppAssets.wordmarkOutline,
      SwipessLogoVariant.transparent ||
      SwipessLogoVariant.white ||
      SwipessLogoVariant.hero => AppAssets.logoTransparent,
    };

    return Image.asset(
      asset,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      errorBuilder: (_, _, _) {
        final px = height ?? ((width ?? 220) * 0.28);
        return Text(
          'SWIPESS',
          style: GoogleFonts.plusJakartaSans(
            color: color ?? Colors.white,
            fontSize: px.clamp(36.0, 88.0),
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        );
      },
    );
  }
}

enum SwipessLogoVariant { transparent, outline, white, hero }
