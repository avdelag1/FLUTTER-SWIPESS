import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Swipess Brand Colors
  static const Color brandPrimary = Color(0xFFFF4D00);
  static const Color brandPrimary2 = Color(0xFFFF6B35);
  static const Color brandPrimary3 = Color(0xFFFF8C42);
  
  static const Color brandAccent = Color(0xFFEC4899);
  static const Color brandAccent2 = Color(0xFFE4007C);

  // Surface Colors for Black Matte
  static const Color surfaceColor = Color(0xFF0A0A0C); 
  static const Color glassBg = Color(0x1CFFFFFF); 
  
  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.dark,
        surface: surfaceColor,
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
