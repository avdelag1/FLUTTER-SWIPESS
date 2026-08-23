import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color brandPrimary = Color(0xFFFF4D00);
  static const Color brandAccent = NexusTheme.rose;
  static const Color brandAccent2 = NexusTheme.mexicanPink;
  static const Color mexicanRed = NexusTheme.mexicanPink;

  static const Color background = Color(0xFF0D1015);
  static const Color surfaceColor = Color(0xFF0D1015);
  static const Color dashBg = Color(0xFF0D1015);
  static const Color dashWell = Color(0xFF141820);
  static const Color dashElevated = Color(0xFF1A2029);

  static const Color lightDashBg = Color(0xFFF2F2F7);
  static const Color lightDashWell = Color(0xFFEDEDF2);
  static const Color lightDashElevated = Color(0xFFFFFFFF);

  static Color canvasFor({required bool isLight}) =>
      isLight ? lightDashBg : dashBg;
  static Color wellFor({required bool isLight}) =>
      isLight ? lightDashWell : dashWell;
  static Color elevatedFor({required bool isLight}) =>
      isLight ? lightDashElevated : dashElevated;

  static const Color dashGlass = Color(0x8A171C25);
  static const Color dashGlassStrong = Color(0xC21A2029);

  // Dark mode deliberately avoids white perimeter strokes. Use contrast,
  // shadow and blur to separate surfaces instead of outlining everything.
  static const Color dashGlassBorder = Colors.transparent;
  static const Color nexusBorder = NexusTheme.border;
  static const Color nexusGlass = NexusTheme.glass;

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD7DDE7);
  static const Color textTertiary = Color(0xFFA8B1C0);

  static const Color brandPrimary2 = Color(0xFFFF6B35);
  static const Color glassBg = Color(0x24FFFFFF);
  static const Color inputFill = Color(0x1CFFFFFF);

  static const LinearGradient warmBrandGradient = NexusTheme.warm;

  static const SystemUiOverlayStyle systemDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: dashBg,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

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

  static const BorderRadius neoNaiveRadius = BorderRadius.only(
    topLeft: Radius.circular(25),
    topRight: Radius.circular(28),
    bottomRight: Radius.circular(23),
    bottomLeft: Radius.circular(27),
  );

  static BoxDecoration get neoNaiveCard => BoxDecoration(
    color: const Color(0xF5141820),
    borderRadius: neoNaiveRadius,
    border: Border.all(color: Colors.transparent),
    boxShadow: const [
      BoxShadow(color: Color(0x46000000), blurRadius: 20, offset: Offset(0, 7)),
    ],
  );

  static BoxDecoration get glassCard => BoxDecoration(
    color: glassBg,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.transparent),
  );

  static BoxDecoration softSurfaceCard({required bool isLight}) =>
      BoxDecoration(
        color: isLight ? Colors.white.withAlpha(220) : dashElevated,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isLight ? Colors.black.withAlpha(24) : Colors.transparent,
        ),
      );

  static final BorderRadius qfNeoFrameRadius = BorderRadius.circular(22);

  static BoxDecoration qfNeoFrame({required bool isLight}) {
    return BoxDecoration(
      color: elevatedFor(isLight: isLight),
      borderRadius: qfNeoFrameRadius,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(isLight ? 22 : 84),
          blurRadius: 13,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  static BoxDecoration dashboardFilterPill({required bool isLight}) =>
      BoxDecoration(
        color: isLight ? const Color(0xFAFFFFFF) : const Color(0xE61A2029),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isLight ? Colors.black.withAlpha(34) : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isLight ? 22 : 72),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static TextStyle get displayItalic => GoogleFonts.plusJakartaSans(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.6,
  );

  static TextStyle get buttonLabel => GoogleFonts.plusJakartaSans(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 14,
    letterSpacing: 1.2,
  );

  static BoxDecoration glassPill({bool glowing = false}) {
    return BoxDecoration(
      color: glassBg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.transparent),
      boxShadow: [
        if (glowing)
          BoxShadow(
            color: brandPrimary.withAlpha(42),
            blurRadius: 24,
            offset: const Offset(0, 7),
          ),
        BoxShadow(
          color: Colors.black.withAlpha(95),
          blurRadius: 20,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }

  static const double radiusCard = 32;

  static TextStyle get kicker => GoogleFonts.plusJakartaSans(
    color: textSecondary,
    fontWeight: FontWeight.w800,
    fontSize: 10,
    letterSpacing: 1.5,
  );

  static BoxDecoration get bottomDockDecoration => BoxDecoration(
    color: dashWell.withAlpha(236),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: Colors.transparent),
    boxShadow: const [
      BoxShadow(
        color: Color(0x70000000),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );

  static ThemeData get darkTheme {
    final base = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: textPrimary, displayColor: textPrimary);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.dark,
        surface: dashWell,
        primary: brandPrimary,
        secondary: brandAccent,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceColor,
      canvasColor: surfaceColor,
      cardColor: dashElevated,
      dividerColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white, size: 22),
      textTheme: base.copyWith(
        bodyLarge: base.bodyLarge?.copyWith(color: textPrimary, height: 1.35),
        bodyMedium: base.bodyMedium?.copyWith(color: textSecondary, height: 1.35),
        bodySmall: base.bodySmall?.copyWith(color: textTertiary, height: 1.3),
        titleLarge: base.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w800),
        titleMedium: base.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        titleSmall: base.titleSmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w700),
        labelLarge: base.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w800),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        systemOverlayStyle: systemDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha(18),
        hintStyle: const TextStyle(color: textTertiary),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: dashElevated,
          disabledForegroundColor: Colors.white54,
          elevation: 0,
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: brandPrimary,
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white54,
          minimumSize: const Size(44, 48),
          side: BorderSide.none,
          backgroundColor: dashElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          backgroundColor: Colors.transparent,
          highlightColor: Colors.white.withAlpha(18),
          hoverColor: Colors.white.withAlpha(12),
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: dashElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        foregroundColor: Colors.white,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme {
    const bg = lightDashBg;
    const surface = lightDashElevated;
    final base = GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme);
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
      textTheme: base,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: Color(0xFF0A0A0D),
        backgroundColor: Colors.transparent,
        systemOverlayStyle: systemLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha(220),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withAlpha(24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withAlpha(24)),
        ),
      ),
      cardColor: surface,
      dividerColor: const Color(0x1A000000),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static BoxDecoration get cinematicGlassDecoration => BoxDecoration(
    color: glassBg,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.transparent),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(105),
        blurRadius: 48,
        offset: const Offset(0, 20),
      ),
      BoxShadow(
        color: Colors.black.withAlpha(48),
        blurRadius: 20,
        offset: const Offset(0, 9),
      ),
    ],
  );
}
