import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cap `tokens.css` + `nexusTheme.ts`
  static const Color brandPrimary = Color(0xFFFF4D00); // --color-brand-primary
  static const Color brandAccent = NexusTheme.rose; // Cap rose / pink accent
  static const Color brandAccent2 = NexusTheme.mexicanPink;
  static const Color mexicanRed =
      NexusTheme.mexicanPink; // Rosa Mexicano #E4007C

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

  // Glass & Borders — Cap soft glass, not hard white frames
  static const Color dashGlass = Color(0x84121218); // rgba(18, 18, 24, 0.52)
  static const Color dashGlassStrong = Color(
    0xB716161E,
  ); // rgba(22, 22, 30, 0.72)
  static const Color dashGlassBorder = Color(
    0x19FFFFFF,
  ); // rgba(255, 255, 255, 0.10)
  static const Color nexusBorder = NexusTheme.border;
  static const Color nexusGlass = NexusTheme.glass;

  // Text Colors
  static const Color textPrimary = Color(0xFFFAFAFA); // --text-primary
  static const Color textSecondary = Color(0xFFBFC6D4); // --text-secondary
  static const Color textTertiary = Color(0xFF8A93A6); // --text-tertiary

  // Backward compatibility
  static const Color brandPrimary2 = Color(0xFFFF6B35);
  static const Color glassBg = Color(0x1CFFFFFF);
  static const Color inputFill = Color(0x14FFFFFF);

  /// Cap warm orange→rose used on dock/profile CTAs.
  static const LinearGradient warmBrandGradient = NexusTheme.warm;

  /// iOS / web status + nav bar chrome for Cap dark matte.
  static const SystemUiOverlayStyle systemDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark, // iOS: dark canvas → light icons
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: dashBg,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  /// Cap white-matte status chrome.
  static const SystemUiOverlayStyle systemLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: lightDashBg,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static SystemUiOverlayStyle systemFor({required bool isLight}) =>
      isLight ? systemLight : systemDark;

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
    border: Border.all(color: const Color(0xEBFFFFFF), width: 1.0),
    boxShadow: const [
      BoxShadow(color: Color(0x59000000), blurRadius: 22, offset: Offset(0, 8)),
    ],
  );

  static BoxDecoration get glassCard => BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white, width: 1.5),
  );

  /// Cap soft surface card (messages/legal panels) — not ink-stamp.
  static BoxDecoration softSurfaceCard({required bool isLight}) =>
      BoxDecoration(
        color: isLight ? Colors.white.withAlpha(200) : NexusTheme.cardDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isLight ? Colors.black.withAlpha(28) : NexusTheme.border,
        ),
      );

  /// Smooth floating quick-filter card — no white ink frame.
  static final BorderRadius qfNeoFrameRadius = BorderRadius.circular(22);

  static BoxDecoration qfNeoFrame({required bool isLight}) {
    return BoxDecoration(
      color: elevatedFor(isLight: isLight),
      borderRadius: qfNeoFrameRadius,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(isLight ? 24 : 105),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Cap `.neo-naive-pill` filter chip on dashboard.
  static BoxDecoration dashboardFilterPill({required bool isLight}) =>
      BoxDecoration(
        color: isLight ? const Color(0xFAFFFFFF) : const Color(0xF50E0E14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isLight ? const Color(0xFF141414) : const Color(0xF2FFFFFF),
          width: 2.5,
        ),
        boxShadow: isLight
            ? const [
                BoxShadow(color: Color(0xFF141414), offset: Offset(1.5, 1.5)),
                BoxShadow(
                  color: Color(0x12141414),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : const [
                BoxShadow(color: Color(0x73FFFFFF), offset: Offset(1.5, 1.5)),
                BoxShadow(color: Color(0x1FFFFFFF), blurRadius: 16),
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
      BoxShadow(
        color: Color(0x99000000),
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.dark,
        surface: surfaceColor,
        primary: brandPrimary,
        secondary: brandAccent,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceColor,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: systemDark,
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
        secondary: brandAccent,
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
        systemOverlayStyle: systemLight,
      ),
      cardColor: surface,
      dividerColor: Color(0x1A000000),
    );
  }

  static BoxDecoration get cinematicGlassDecoration => BoxDecoration(
    color: glassBg,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withAlpha(51), width: 1),
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
}
