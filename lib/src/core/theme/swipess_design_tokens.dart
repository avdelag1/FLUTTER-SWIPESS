import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swipess Modernized Design Tokens
abstract final class SwipessTokens {
  // Geometry
  static const double radiusCard = 28.0;
  static const double radiusTile = 22.0;
  static const double radiusPill = 999.0;

  static const double heightCTA = 54.0;
  static const double heightCompactCTA = 44.0;

  // Spacing & Padding
  static const EdgeInsets paddingCard = EdgeInsets.all(20.0);
  static const EdgeInsets paddingTile = EdgeInsets.all(16.0);

  // Surface Colors
  static const Color darkCanvas = Color(0xFF0A0A0D);
  static const Color darkWell = Color(0xFF121218);
  static const Color darkElevated = Color(0xFF181822);
  static const Color darkBorder = Color(0x1AFFFFFF); // 10% white stroke

  static const Color lightCanvas = Color(0xFFF2F2F7);
  static const Color lightWell = Color(0xFFE5E5EA);
  static const Color lightElevated = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0x1F000000); // 12% black stroke

  // Tier Atmospheres & Accent Colors
  static const Color tierStarter = Color(0xFF818CF8); // Soft indigo / violet
  static const Color tierPlus = Color(0xFFEC4899);    // Hot pink / rose
  static const Color tierPower = Color(0xFFF59E0B);   // Warm gold / amber
  static const Color tierMega = Color(0xFFEF4444);    // Coral / red
  static const Color tierPremium = Color(0xFFF59E0B); // Premium gold
  static const Color brandOrange = Color(0xFFFF4D00);  // Swipess primary

  // Typography Hierarchy
  static TextStyle displayItalic({Color color = Colors.white, double fontSize = 24.0}) =>
      GoogleFonts.plusJakartaSans(
        color: color,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        fontSize: fontSize,
        letterSpacing: -0.8,
        height: 1.1,
      );

  static TextStyle priceOversized({Color color = Colors.white, double fontSize = 32.0}) =>
      GoogleFonts.plusJakartaSans(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        letterSpacing: -1.0,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle kickerUppercase({Color color = const Color(0x99FFFFFF), double fontSize = 11.0}) =>
      GoogleFonts.plusJakartaSans(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: fontSize,
        letterSpacing: 1.8,
      );

  static TextStyle bodyClean({Color color = const Color(0xCCFFFFFF), double fontSize = 13.0}) =>
      GoogleFonts.plusJakartaSans(
        color: color,
        fontWeight: FontWeight.w500,
        fontSize: fontSize,
        height: 1.35,
      );

  // Soft Depth Shadows (No thick outlines)
  static List<BoxShadow> cardShadow({Color accent = Colors.black, bool isLight = false}) {
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
