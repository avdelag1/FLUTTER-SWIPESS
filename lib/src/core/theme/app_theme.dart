import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
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
  static const Color dashGlassBorder = Colors.transparent;
  static const Color nexusBorder = NexusTheme.border;
  static const Color nexusGlass = NexusTheme.glass;

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFFFFFFF);
  static const Color textTertiary = Color(0xFFFFFFFF);

  static const Color brandPrimary2 = Color(0xFFFF6B35);
  static const Color glassBg = Color(0x24FFFFFF);
  static const Color inputFill = Color(0x1CFFFFFF);
  static const LinearGradient warmBrandGradient = NexusTheme.warm;

  static const SystemUiOverlayStyle systemDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const SystemUiOverlayStyle systemLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
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

  static BoxDecoration softSurfaceCard({required bool isLight}) => BoxDecoration(
    color: isLight ? Colors.white.withAlpha(220) : dashElevated,
    borderRadius: BorderRadius.circular(SwipessTokens.radiusCard),
    border: Border.all(
      color: isLight ? Colors.black.withAlpha(24) : Colors.transparent,
    ),
    boxShadow: SwipessTokens.cardShadow(isLight: isLight),
  );

  static final BorderRadius qfNeoFrameRadius =
      BorderRadius.circular(SwipessTokens.radiusTile);

  static BoxDecoration qfNeoFrame({required bool isLight}) => BoxDecoration(
    color: elevatedFor(isLight: isLight),
    borderRadius: qfNeoFrameRadius,
    border: Border.all(
      color: isLight ? Colors.black.withAlpha(18) : Colors.transparent,
    ),
    boxShadow: SwipessTokens.cardShadow(isLight: isLight),
  );

  static BoxDecoration dashboardFilterPill({required bool isLight}) =>
      BoxDecoration(
        color: isLight ? const Color(0xFAFFFFFF) : const Color(0xE61A2029),
        borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
        border: Border.all(
          color: isLight ? Colors.black.withAlpha(30) : Colors.transparent,
        ),
        boxShadow: SwipessTokens.cardShadow(isLight: isLight),
      );

  static TextStyle get displayItalic => SwipessTokens.displayItalic();
  static TextStyle get buttonLabel => SwipessTokens.buttonLabel(fontSize: 14);

  static BoxDecoration glassPill({bool glowing = false}) => BoxDecoration(
    color: glassBg,
    borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
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

  static const double radiusCard = 32;
  static TextStyle get kicker =>
      SwipessTokens.kickerUppercase(color: textSecondary, fontSize: 10);

  static BoxDecoration get bottomDockDecoration => BoxDecoration(
    color: dashWell.withAlpha(236),
    borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
    border: Border.all(color: Colors.transparent),
    boxShadow: const [
      BoxShadow(
        color: Color(0x70000000),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );

  static TextStyle _buttonStyle(Color color) => GoogleFonts.plusJakartaSans(
    color: color,
    fontWeight: FontWeight.w900,
    fontSize: 12.5,
    letterSpacing: .65,
  );

  static InputDecorationTheme _inputTheme({required bool isLight}) {
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final fill = isLight ? Colors.white.withAlpha(230) : Colors.white.withAlpha(15);
    final idle = isLight ? Colors.black.withAlpha(24) : Colors.white.withAlpha(22);
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: ink.withAlpha(105),
        fontWeight: FontWeight.w600,
      ),
      labelStyle: GoogleFonts.plusJakartaSans(
        color: ink.withAlpha(170),
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        borderSide: BorderSide(color: idle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        borderSide: BorderSide(color: idle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        borderSide: BorderSide(color: brandAccent2.withAlpha(190), width: 1.35),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        borderSide: const BorderSide(color: SwipessTokens.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        borderSide: const BorderSide(color: SwipessTokens.danger, width: 1.35),
      ),
    );
  }

  static FilledButtonThemeData _filledTheme({required bool isLight}) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: brandPrimary,
          disabledForegroundColor: Colors.white.withAlpha(170),
          disabledBackgroundColor:
              isLight ? Colors.black.withAlpha(30) : Colors.white.withAlpha(22),
          minimumSize: const Size(44, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
          ),
          textStyle: _buttonStyle(Colors.white),
        ),
      );

  static ElevatedButtonThemeData _elevatedTheme({required bool isLight}) {
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: isLight ? Colors.white : dashElevated,
        disabledForegroundColor: ink.withAlpha(120),
        disabledBackgroundColor:
            isLight ? Colors.black.withAlpha(22) : Colors.white.withAlpha(18),
        elevation: 0,
        minimumSize: const Size(44, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        ),
        textStyle: _buttonStyle(ink),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedTheme({required bool isLight}) {
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        disabledForegroundColor: ink.withAlpha(120),
        minimumSize: const Size(44, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(
          color: isLight ? Colors.black.withAlpha(30) : Colors.white.withAlpha(28),
        ),
        backgroundColor: isLight ? Colors.white.withAlpha(180) : dashElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        ),
        textStyle: _buttonStyle(ink),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme({required bool isLight}) {
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        disabledForegroundColor: ink.withAlpha(105),
        minimumSize: const Size(40, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwipessTokens.radiusCompact),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }

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
      ).copyWith(
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white,
        outline: Colors.white.withAlpha(35),
        outlineVariant: Colors.white.withAlpha(20),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceColor,
      canvasColor: surfaceColor,
      cardColor: dashElevated,
      dividerColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white, size: 21),
      textTheme: base.copyWith(
        bodyLarge: base.bodyLarge?.copyWith(color: textPrimary, height: 1.35),
        bodyMedium: base.bodyMedium?.copyWith(color: textSecondary, height: 1.35),
        bodySmall: base.bodySmall?.copyWith(color: textTertiary, height: 1.3),
        titleLarge: base.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w900),
        titleMedium: base.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w800),
        titleSmall: base.titleSmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w700),
        labelLarge: base.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w900),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        systemOverlayStyle: systemDark,
      ),
      inputDecorationTheme: _inputTheme(isLight: false),
      elevatedButtonTheme: _elevatedTheme(isLight: false),
      filledButtonTheme: _filledTheme(isLight: false),
      outlinedButtonTheme: _outlinedTheme(isLight: false),
      textButtonTheme: _textButtonTheme(isLight: false),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withAlpha(105),
          backgroundColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.white.withAlpha(8),
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: dashElevated,
        selectedColor: brandAccent2.withAlpha(40),
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dashElevated,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: dashWell,
        modalBackgroundColor: dashWell,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        foregroundColor: Colors.white,
      ),
      pageTransitionsTheme: _pageTransitions,
    );
  }

  static ThemeData get lightTheme {
    const bg = lightDashBg;
    const surface = lightDashElevated;
    const ink = Color(0xFF0A0A0D);
    final base = GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme)
        .apply(bodyColor: ink, displayColor: ink);

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
      canvasColor: bg,
      cardColor: surface,
      dividerColor: const Color(0x12000000),
      iconTheme: const IconThemeData(color: ink, size: 21),
      textTheme: base.copyWith(
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: ink,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: systemLight,
      ),
      inputDecorationTheme: _inputTheme(isLight: true),
      elevatedButtonTheme: _elevatedTheme(isLight: true),
      filledButtonTheme: _filledTheme(isLight: true),
      outlinedButtonTheme: _outlinedTheme(isLight: true),
      textButtonTheme: _textButtonTheme(isLight: true),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          disabledForegroundColor: ink.withAlpha(100),
          backgroundColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.black.withAlpha(6),
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: Colors.white,
        selectedColor: brandAccent2.withAlpha(22),
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      pageTransitionsTheme: _pageTransitions,
    );
  }

  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    },
  );

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
