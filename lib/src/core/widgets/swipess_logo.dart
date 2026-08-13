import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor wordmark. Always the transparent-plate PNG so only the
/// italic SWIPESS letters show — no black box around the type.
class SwipessLogo extends StatelessWidget {
  const SwipessLogo({
    super.key,
    this.height,
    this.width,
    this.variant = SwipessLogoVariant.transparent,
  });

  final double? height;
  final double? width;
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
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) {
        final px = height ?? ((width ?? 220) * 0.28);
        return Text(
          'SWIPESS',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
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

enum SwipessLogoVariant { transparent, outline, white }
