import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';

/// Cap black-matte / white-matte surface helpers from [ThemeData.brightness].
abstract final class MatteSurface {
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color canvas(BuildContext context) =>
      AppTheme.canvasFor(isLight: isLight(context));

  static Color well(BuildContext context) =>
      AppTheme.wellFor(isLight: isLight(context));

  static Color elevated(BuildContext context) =>
      AppTheme.elevatedFor(isLight: isLight(context));

  /// Primary ink on matte canvas.
  static Color ink(BuildContext context) =>
      isLight(context) ? const Color(0xFF0A0A0D) : Colors.white;

  /// Dark-mode secondary text is intentionally bright. The old gray values
  /// made labels and metadata disappear against the black surfaces.
  static Color muted(BuildContext context) =>
      isLight(context) ? const Color(0xFF5C5C66) : Colors.white;

  /// Tertiary / placeholder ink. Keep dark mode bright enough to read.
  static Color faint(BuildContext context) =>
      isLight(context) ? const Color(0xFF8A8A96) : Colors.white;

  /// Cap soft hairline — dark mode uses no white perimeter strokes.
  static Color hairline(BuildContext context) =>
      isLight(context) ? Colors.black.withAlpha(28) : Colors.transparent;

  /// Cap soft panel fill — `#141418` dark / white light.
  static Color cardFill(BuildContext context) =>
      isLight(context) ? Colors.white : NexusTheme.cardDark;

  static Color accent(BuildContext context) => AppTheme.brandAccent;

  static Color glass(BuildContext context) =>
      isLight(context) ? Colors.white.withAlpha(180) : NexusTheme.glass;
}
