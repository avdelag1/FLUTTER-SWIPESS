import 'package:flutter/material.dart';

/// Cap `CARD_THEMES` — Pearl, Obsidian, Rosa Mexicano, Jungle, Nexus.
class VapCardTheme {
  const VapCardTheme({
    required this.name,
    required this.gradient,
    required this.accent,
    required this.badge,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.tagBg,
    required this.tagBorder,
    required this.tagText,
    required this.isDark,
    this.swatch = Colors.white,
  });

  final String name;
  final List<Color> gradient;
  final Color accent;
  final Color badge;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color tagBg;
  final Color tagBorder;
  final Color tagText;
  final bool isDark;
  /// Small circle shown in the color picker row.
  final Color swatch;

  static const themes = <VapCardTheme>[
    VapCardTheme(
      name: 'Pearl',
      gradient: [Color(0xFFFAFAF9), Color(0xFFF5F5F4), Color(0xFFE7E5E4)],
      accent: Color(0xFF525252),
      badge: Color(0xFF404040),
      textPrimary: Color(0xFF1A1A1A),
      textSecondary: Color(0x99000000),
      textTertiary: Color(0x59000000),
      tagBg: Color(0x0A000000),
      tagBorder: Color(0x14000000),
      tagText: Color(0x8C000000),
      isDark: false,
      swatch: Color(0xFFF5F5F4),
    ),
    VapCardTheme(
      name: 'Obsidian',
      gradient: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF111111)],
      accent: Color(0xFFA0A0A0),
      badge: Color(0xFFC0C0C0),
      textPrimary: Colors.white,
      textSecondary: Color(0xB3FFFFFF),
      textTertiary: Color(0x66FFFFFF),
      tagBg: Color(0x0FFFFFFF),
      tagBorder: Color(0x14FFFFFF),
      tagText: Color(0x99FFFFFF),
      isDark: true,
      swatch: Color(0xFF1A1A1A),
    ),
    VapCardTheme(
      name: 'Rosa Mexicano',
      gradient: [Color(0xFFC2185B), Color(0xFFE91E63), Color(0xFFAD1457)],
      accent: Color(0xFFFCE4EC),
      badge: Color(0xFFFFF0F5),
      textPrimary: Colors.white,
      textSecondary: Color(0xD9FFFFFF),
      textTertiary: Color(0x8CFFFFFF),
      tagBg: Color(0x1FFFFFFF),
      tagBorder: Color(0x26FFFFFF),
      tagText: Color(0xCCFFFFFF),
      isDark: true,
      swatch: Color(0xFFE91E63),
    ),
    VapCardTheme(
      name: 'Jungle',
      gradient: [Color(0xFF1B3A2D), Color(0xFF2D5A3F), Color(0xFF1A4030)],
      accent: Color(0xFF81C784),
      badge: Color(0xFFA5D6A7),
      textPrimary: Colors.white,
      textSecondary: Color(0xBFFFFFFF),
      textTertiary: Color(0x73FFFFFF),
      tagBg: Color(0x12FFFFFF),
      tagBorder: Color(0x1AFFFFFF),
      tagText: Color(0xA6FFFFFF),
      isDark: true,
      swatch: Color(0xFF2D5A3F),
    ),
    VapCardTheme(
      name: 'Nexus',
      gradient: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4C1D95)],
      accent: Color(0xFFC4B5FD),
      badge: Color(0xFFEDE9FE),
      textPrimary: Colors.white,
      textSecondary: Color(0xD1FFFFFF),
      textTertiary: Color(0x80FFFFFF),
      tagBg: Color(0x1F8B5CF6),
      tagBorder: Color(0x38A78BFA),
      tagText: Color(0xE6EDE9FE),
      isDark: true,
      swatch: Color(0xFF6366F1),
    ),
  ];
}
