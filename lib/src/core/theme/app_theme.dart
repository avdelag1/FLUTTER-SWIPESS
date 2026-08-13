import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Swipess Brand Colors
  static const Color brandPrimary = Color(0xFFFF4D00); // --btn-primary-bg
  static const Color brandAccent = Color(0xFFFC567E); // --accent-primary
  /// Rosa Mexicano — Cap `--color-brand-accent-2` / mexican-pink. The
  /// vivid red-magenta the landing CTA and hero wordmark use when we
  /// need a punchier fill than orange `#FF4D00`.
  static const Color mexicanRed = Color(0xFFE4007C);

  // Black Matte Backgrounds
  static const Color background = Color(0xFF0C0C0D); // --background
  static const Color surfaceColor = Color(0xFF0C0C0D); 
  
  // Dashboard Depth Layers (black-matte)
  static const Color dashBg = Color(0xFF0A0A0D); // --dash-bg
  static const Color dashWell = Color(0xFF101014); // --dash-well
  static const Color dashElevated = Color(0xFF16161C); // --dash-elevated

  // Cap `.light` / `.white-matte` dash layers
  static const Color lightDashBg = Color(0xFFF2F2F7);
  static const Color lightDashWell = Color(0xFFE8E8EE);
  static const Color lightDashElevated = Color(0xFFFFFFFF);

  static Color canvasFor({required bool isLight}) =>
      isLight ? lightDashBg : dashBg;

  static Color wellFor({required bool isLight}) =>
      isLight ? lightDashWell : dashWell;

  static Color elevatedFor({required bool isLight}) =>
      isLight ? lightDashElevated : dashElevated;
  
  // Glass & Borders
  static const Color dashGlass = Color(0x84121218); // rgba(18, 18, 24, 0.52)
  static const Color dashGlassStrong = Color(0xB716161E); // rgba(22, 22, 30, 0.72)
  static const Color dashGlassBorder = Color(0x19FFFFFF); // rgba(255, 255, 255, 0.10)
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFAFAFA); // --text-primary
  static const Color textSecondary = Color(0xFFBFC6D4); // --text-secondary
  static const Color textTertiary = Color(0xFF8A93A6); // --text-tertiary

  // Backward compatibility
  static const Color brandPrimary2 = Color(0xFFFF6B35);
  static const Color glassBg = Color(0x1CFFFFFF);
  static const Color inputFill = Color(0x14FFFFFF);

  /// Cap neo-naive ink-stamp card (dark). Organic radii, 2.25px frame.
  static const BorderRadius neoNaiveRadius = BorderRadius.only(
    topLeft: Radius.circular(25),
    topRight: Radius.circular(28),
    bottomRight: Radius.circular(23),
    bottomLeft: Radius.circular(27),
  );

  static BoxDecoration get neoNaiveCard => BoxDecoration(
        color: const Color(0xF50E0E14),
        borderRadius: neoNaiveRadius,
        border: Border.all(color: const Color(0xEBFFFFFF), width: 2.25),
        boxShadow: const [
          BoxShadow(color: Color(0x66FFFFFF), offset: Offset(1.5, 1.5)),
          BoxShadow(color: Color(0x59000000), blurRadius: 22, offset: Offset(0, 8)),
        ],
      );

  static BoxDecoration get glassCard => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
      );

  /// Cap `.qf-neo-frame` — organic ink-stamp border on quick-filter cards.
  static const BorderRadius qfNeoFrameRadius = BorderRadius.only(
    topLeft: Radius.circular(29.6),
    topRight: Radius.circular(32.8),
    bottomRight: Radius.circular(28),
    bottomLeft: Radius.circular(32),
  );

  static BoxDecoration qfNeoFrame({required bool isLight}) => BoxDecoration(
        color: elevatedFor(isLight: isLight),
        borderRadius: qfNeoFrameRadius,
        border: Border.all(
          color: isLight
              ? const Color(0x85141414)
              : const Color(0x6BFFFFFF),
          width: 1.75,
        ),
        boxShadow: isLight
            ? const [
                BoxShadow(
                  color: Color(0x47141414),
                  offset: Offset(1, 1),
                ),
                BoxShadow(
                  color: Color(0x6B000000),
                  blurRadius: 32,
                  offset: Offset(0, -12),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x38FFFFFF),
                  offset: Offset(1, 1),
                ),
                BoxShadow(
                  color: Color(0x0FFFFFFF),
                  blurRadius: 14,
                ),
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 36,
                  offset: Offset(0, -12),
                ),
              ],
      );

  /// Cap `.neo-naive-pill` filter chip on dashboard.
  static BoxDecoration dashboardFilterPill({required bool isLight}) =>
      BoxDecoration(
        color: isLight
            ? const Color(0xFAFFFFFF)
            : const Color(0xF50E0E14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isLight
              ? const Color(0xFF141414)
              : const Color(0xF2FFFFFF),
          width: 2.5,
        ),
        boxShadow: isLight
            ? const [
                BoxShadow(
                  color: Color(0xFF141414),
                  offset: Offset(1.5, 1.5),
                ),
                BoxShadow(
                  color: Color(0x12141414),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x73FFFFFF),
                  offset: Offset(1.5, 1.5),
                ),
                BoxShadow(
                  color: Color(0x1FFFFFFF),
                  blurRadius: 16,
                ),
              ],
      );

  static TextStyle get displayItalic => GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -1.0,
      );

  static TextStyle get buttonLabel => GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 14,
        letterSpacing: 2.2,
      );

  static BoxDecoration glassPill({bool glowing = false}) {
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: [
        if (glowing)
          BoxShadow(
            color: brandPrimary.withAlpha(50),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        BoxShadow(
          color: Colors.black.withAlpha(150),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static const double radiusCard = 32;

  static TextStyle get kicker => GoogleFonts.plusJakartaSans(
        color: const Color(0xB3FFFFFF),
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: 2,
      );

  static BoxDecoration get bottomDockDecoration => BoxDecoration(
        color: dashWell.withAlpha(240),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.transparent, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      );

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.dark,
        surface: surfaceColor,
        primary: brandPrimary,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceColor,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  /// Cap `white-matte` / light theme.
  static ThemeData get lightTheme {
    const bg = lightDashBg;
    const surface = lightDashElevated;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.light,
        surface: surface,
        primary: brandPrimary,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        foregroundColor: Color(0xFF0A0A0D),
      ),
      cardColor: surface,
      dividerColor: Color(0x1A000000),
    );
  }

  static BoxDecoration get cinematicGlassDecoration => BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha(51), // 0.2 opacity
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(127), // 0.5 opacity
            blurRadius: 64,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(63), // 0.25 opacity
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      );
}
