import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

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

  static Color muted(BuildContext context) => isLight(context)
      ? const Color(0xFF5C5C66)
      : AppTheme.textSecondary;

  static Color hairline(BuildContext context) =>
      isLight(context) ? Colors.black.withAlpha(28) : Colors.white.withAlpha(40);

  static Color cardFill(BuildContext context) => isLight(context)
      ? Colors.white
      : Colors.white.withAlpha(12);
}
