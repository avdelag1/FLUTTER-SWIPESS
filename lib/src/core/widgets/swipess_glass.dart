import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared visual language for messaging + AI conversation surfaces.
///
/// The goal is a dark charcoal / pearl-light matte glass treatment that keeps
/// controls readable while allowing the page behind a sheet to remain subtly
/// visible. Widgets here are intentionally dependency-free so both core chat
/// and Intel can use the same language.
abstract final class SwipessGlassLook {
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color canvas(BuildContext context) =>
      isLight(context) ? const Color(0xFFF4F4F7) : const Color(0xFF0B0E13);

  static Color ink(BuildContext context) =>
      isLight(context) ? const Color(0xFF0A0A0D) : const Color(0xFFF8FAFC);

  static Color muted(BuildContext context) =>
      isLight(context) ? const Color(0xFF72727D) : const Color(0xFFB7BDC8);

  static Color faint(BuildContext context) =>
      isLight(context) ? const Color(0xFF9696A0) : const Color(0xFF7C8491);

  static Color panel(BuildContext context) => isLight(context)
      ? const Color(0xDDFDFDFE)
      : const Color(0xD91A1E27);

  static Color panelStrong(BuildContext context) => isLight(context)
      ? const Color(0xF6FFFFFF)
      : const Color(0xF2161921);

  static Color field(BuildContext context) => isLight(context)
      ? const Color(0xCCECEEF3)
      : const Color(0xCC11151C);

  static Color hairline(BuildContext context) => isLight(context)
      ? const Color(0x1A101217)
      : const Color(0x24FFFFFF);

  static const Color accent = Color(0xFFFF3D78);
  static const Color accentWarm = Color(0xFFFF5A36);
  static const Color ai = Color(0xFF4F6BFF);
  static const Color aiSoft = Color(0xFF7B8DFF);

  static List<BoxShadow> shadow(BuildContext context, {bool strong = false}) => [
        BoxShadow(
          color: Colors.black.withAlpha(isLight(context) ? (strong ? 38 : 20) : (strong ? 110 : 64)),
          blurRadius: strong ? 30 : 18,
          offset: Offset(0, strong ? 12 : 7),
        ),
      ];
}

class SwipessGlassPanel extends StatelessWidget {
  const SwipessGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 24,
    this.blur = 20,
    this.strong = false,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blur;
  final bool strong;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: strong
                  ? SwipessGlassLook.panelStrong(context)
                  : SwipessGlassLook.panel(context),
              borderRadius: shape,
              border: border
                  ? Border.all(color: SwipessGlassLook.hairline(context))
                  : null,
              boxShadow: SwipessGlassLook.shadow(context, strong: strong),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SwipessGlassIconButton extends StatelessWidget {
  const SwipessGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 42,
    this.iconSize = 19,
    this.tooltip,
    this.accent,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;
  final double iconSize;
  final String? tooltip;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? SwipessGlassLook.accent;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: active ? color.withAlpha(26) : SwipessGlassLook.field(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? color.withAlpha(95) : SwipessGlassLook.hairline(context),
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: active ? color : SwipessGlassLook.ink(context),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class SwipessSendButton extends StatelessWidget {
  const SwipessSendButton({
    super.key,
    required this.enabled,
    required this.onTap,
    this.loading = false,
    this.ai = false,
    this.size = 50,
  });

  final bool enabled;
  final VoidCallback onTap;
  final bool loading;
  final bool ai;
  final double size;

  @override
  Widget build(BuildContext context) {
    final activeA = ai ? SwipessGlassLook.ai : SwipessGlassLook.accentWarm;
    final activeB = ai ? SwipessGlassLook.aiSoft : SwipessGlassLook.accent;
    return Semantics(
      button: true,
      enabled: enabled && !loading,
      label: 'Send',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !loading ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [activeA, activeB],
                  )
                : null,
            color: enabled ? null : SwipessGlassLook.field(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(9),
            ),
            border: Border.all(
              color: enabled ? activeB.withAlpha(90) : SwipessGlassLook.hairline(context),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: activeB.withAlpha(62),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: loading
              ? Padding(
                  padding: EdgeInsets.all(size * .31),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  color: enabled ? Colors.white : SwipessGlassLook.faint(context),
                  size: size * .43,
                ),
        ),
      ),
    );
  }
}
