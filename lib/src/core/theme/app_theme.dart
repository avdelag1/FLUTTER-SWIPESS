import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swipess design tokens translated from Capacitor `tokens.css` + `matte-themes.css`.
class AppTheme {
  AppTheme._();

  static const Color brandPrimary = Color(0xFFFF4D00);
  static const Color brandPrimary2 = Color(0xFFFF6B35);
  static const Color brandPrimary3 = Color(0xFFFF8C42);
  static const Color brandAccent = Color(0xFFEC4899);
  static const Color brandAccent2 = Color(0xFFE4007C);

  static const Color surfaceColor = Color(0xFF0A0A0C);
  static const Color dashBg = Color(0xFF0A0A0D);
  static const Color dashWell = Color(0xFF101014);
  static const Color glassBg = Color(0x1CFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color inputFill = Color(0x26FFFFFF);

  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 28;
  static const double radius2xl = 36;
  static const double radiusCard = 40;

  static ThemeData get darkTheme {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.dark,
        surface: surfaceColor,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceColor,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static TextStyle get displayItalic => GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -1.4,
        height: 0.88,
      );

  static TextStyle get kicker => GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        fontSize: 10,
        letterSpacing: 3.2,
      );

  static TextStyle get buttonLabel => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        letterSpacing: 2.4,
      );

  static BoxDecoration get cinematicGlassDecoration => BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(127),
            blurRadius: 64,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(63),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      );

  static BoxDecoration get gatePanelDecoration => BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(140),
            blurRadius: 48,
            offset: const Offset(0, 24),
          ),
        ],
      );

  static BoxDecoration glassPill({bool wide = false}) => BoxDecoration(
        color: const Color(0x85101016),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xE6FFFFFF), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59FFFFFF),
            offset: Offset(1.25, 1.25),
          ),
          BoxShadow(
            color: Color(0x24FFFFFF),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration get bottomDockDecoration => BoxDecoration(
        color: const Color(0x7A101016),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xE6FFFFFF), width: 2.25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59FFFFFF),
            offset: Offset(1.5, 1.5),
          ),
          BoxShadow(
            color: Color(0x24FFFFFF),
            blurRadius: 22,
          ),
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      );
}
