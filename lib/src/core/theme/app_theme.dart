import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Swipess Brand Colors
  static const Color brandPrimary = Color(0xFFFF4D00); // --btn-primary-bg
  static const Color brandAccent = Color(0xFFFC567E); // --accent-primary

  // Black Matte Backgrounds
  static const Color background = Color(0xFF0C0C0D); // --background
  static const Color surfaceColor = Color(0xFF0C0C0D); 
  
  // Dashboard Depth Layers
  static const Color dashBg = Color(0xFF0A0A0D); // --dash-bg
  static const Color dashWell = Color(0xFF101014); // --dash-well
  static const Color dashElevated = Color(0xFF16161C); // --dash-elevated
  
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
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
