import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:google_fonts/google_fonts.dart';

class SwipessLogo extends StatelessWidget {
  const SwipessLogo({
    super.key,
    this.height = 40,
    this.variant = SwipessLogoVariant.transparent,
  });

  final double height;
  final SwipessLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final asset = switch (variant) {
      SwipessLogoVariant.transparent => AppAssets.logoTransparent,
      SwipessLogoVariant.outline => AppAssets.wordmarkOutline,
      SwipessLogoVariant.white => AppAssets.wordmarkWhite,
    };

    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Text(
        'SWIPESS',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: height * 0.55,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

enum SwipessLogoVariant { transparent, outline, white }
