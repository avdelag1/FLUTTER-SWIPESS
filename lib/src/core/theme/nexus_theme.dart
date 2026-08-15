import 'package:flutter/material.dart';

/// Cap `nexusTheme.ts` + `tokens.css` — rose / violet / indigo secret palette.
abstract final class NexusTheme {
  static const Color rose = Color(0xFFEB4898);
  static const Color roseToken = Color(0xFFEC4899); // --color-brand-accent
  static const Color mexicanPink = Color(0xFFE4007C); // --color-brand-accent-2
  static const Color violet = Color(0xFF8B5CF6);
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoDeep = Color(0xFF4F46E5);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color shell = Color(0xFF0A0A0B);
  static const Color cardDark = Color(0xFF141418);

  /// Cap `NEXUS.glass` / `border`
  static const Color glass = Color(0x0AFFFFFF); // 0.04
  static const Color border = Color(0x14FFFFFF); // 0.08

  static const Color glowPrimary = Color(0x99FF4D00); // ~0.6
  static const Color glowAccent = Color(0x80EB4898); // ~0.5

  /// Cap `NEXUS_GRADIENTS.warm` — orange → rose (profile / dock active).
  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
  );

  /// Cap `NEXUS_GRADIENTS.cta` — rose → violet.
  static const LinearGradient cta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEB4898), Color(0xFF8B5CF6)],
  );

  /// Cap `NEXUS_GRADIENTS.ai` — cyan → indigo → violet.
  static const LinearGradient ai = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  /// Cap `NEXUS_GRADIENTS.owner` — violet → indigo.
  static const LinearGradient owner = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
  );

  /// Cap brand gradient for badges — accent → primary.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEB4898), Color(0xFFFF4D00)],
  );

  /// Cap `nexusGlassCard` fill.
  static BoxDecoration glassCard({
    double radius = 32,
    Color? borderColor,
    Color? fill,
  }) {
    return BoxDecoration(
      color: fill ?? glass,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border),
    );
  }

  static TextStyle get sectionLabel => const TextStyle(
    color: violet,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.8,
  );
}
