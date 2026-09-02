import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Canonical Swipess visual language.
///
/// Keep geometry, type, motion and responsive rules here so individual screens
/// do not invent slightly different versions of the same UI.
abstract final class SwipessTokens {
  // Geometry
  static const double radiusCard = 28.0;
  static const double radiusTile = 22.0;
  static const double radiusControl = 18.0;
  static const double radiusCompact = 14.0;
  static const double radiusPill = 999.0;

  static const double heightCTA = 54.0;
  static const double heightCompactCTA = 44.0;
  static const double iconActionSize = 44.0;
  static const double iconActionCompactSize = 38.0;
  static const double iconSize = 21.0;

  // Spacing scale
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;

  static const EdgeInsets paddingCard = EdgeInsets.all(20.0);
  static const EdgeInsets paddingTile = EdgeInsets.all(16.0);

  // Responsive layout
  static const double breakpointNarrow = 380.0;
  static const double breakpointPhone = 700.0;
  static const double breakpointTablet = 1100.0;
  static const double readingMaxWidth = 760.0;
  static const double contentMaxWidth = 1180.0;

  static double pagePaddingFor(double width) {
    if (width < breakpointNarrow) return 14;
    if (width < breakpointPhone) return 18;
    if (width < breakpointTablet) return 28;
    return 36;
  }

  static double heroTopGapFor(double width) {
    if (width < breakpointPhone) return 12;
    if (width < breakpointTablet) return 28;
    return 36;
  }

  // Motion
  static const Duration motionFast = Duration(milliseconds: 90);
  static const Duration motionNormal = Duration(milliseconds: 180);
  static const Duration motionSlow = Duration(milliseconds: 280);
  static const double pressScale = 0.975;
  static const double hoverScale = 1.006;

  // Surface colors
  static const Color darkCanvas = Color(0xFF0A0A0D);
  static const Color darkWell = Color(0xFF121218);
  static const Color darkElevated = Color(0xFF181822);
  static const Color darkBorder = Colors.transparent;

  static const Color lightCanvas = Color(0xFFF2F2F7);
  static const Color lightWell = Color(0xFFE5E5EA);
  static const Color lightElevated = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0x1F000000);

  // Brand / feature accents
  static const Color brandOrange = Color(0xFFFF4D00);
  static const Color brandPink = Color(0xFFE4007C);
  static const Color brandViolet = Color(0xFF9D4EDD);
  static const Color brandBlue = Color(0xFF3B82F6);
  static const Color success = Color(0xFF34C759);
  static const Color danger = Color(0xFFEF4444);

  // Tier atmospheres
  static const Color tierStarter = Color(0xFF818CF8);
  static const Color tierPlus = Color(0xFFEC4899);
  static const Color tierPower = Color(0xFFF59E0B);
  static const Color tierMega = Color(0xFFEF4444);
  static const Color tierPremium = Color(0xFFF59E0B);

  // Typography hierarchy
  static TextStyle displayItalic({
    Color color = Colors.white,
    double fontSize = 24.0,
  }) => GoogleFonts.plusJakartaSans(
    color: color,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    fontSize: fontSize,
    letterSpacing: -0.8,
    height: 1.08,
  );

  static TextStyle titleStrong({
    Color color = Colors.white,
    double fontSize = 18.0,
  }) => GoogleFonts.plusJakartaSans(
    color: color,
    fontWeight: FontWeight.w900,
    fontSize: fontSize,
    letterSpacing: -0.35,
    height: 1.12,
  );

  static TextStyle buttonLabel({
    Color color = Colors.white,
    double fontSize = 12.5,
  }) => GoogleFonts.plusJakartaSans(
    color: color,
    fontWeight: FontWeight.w900,
    fontSize: fontSize,
    letterSpacing: 0.8,
    height: 1.0,
  );

  static TextStyle priceOversized({
    Color color = Colors.white,
    double fontSize = 32.0,
  }) => GoogleFonts.plusJakartaSans(
    color: color,
    fontWeight: FontWeight.w900,
    fontSize: fontSize,
    letterSpacing: -1.0,
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle kickerUppercase({
    Color color = const Color(0x99FFFFFF),
    double fontSize = 11.0,
  }) => GoogleFonts.plusJakartaSans(
    color: color,
    fontWeight: FontWeight.w800,
    fontSize: fontSize,
    letterSpacing: 1.4,
    height: 1.15,
  );

  static TextStyle bodyClean({
    Color color = const Color(0xCCFFFFFF),
    double fontSize = 13.0,
  }) => GoogleFonts.plusJakartaSans(
    color: color,
    fontWeight: FontWeight.w500,
    fontSize: fontSize,
    height: 1.42,
  );

  static TextStyle meta({
    Color color = const Color(0x99FFFFFF),
    double fontSize = 10.5,
  }) => GoogleFonts.plusJakartaSans(
    color: color,
    fontWeight: FontWeight.w700,
    fontSize: fontSize,
    letterSpacing: 0.15,
    height: 1.25,
  );

  // Soft depth shadows. Dark mode avoids white perimeter strokes.
  static List<BoxShadow> cardShadow({
    Color accent = Colors.black,
    bool isLight = false,
  }) {
    if (isLight) {
      return [
        BoxShadow(
          color: Colors.black.withAlpha(16),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
    }
    return [
      BoxShadow(
        color: accent.withAlpha(24),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withAlpha(120),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }
}
