import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';

/// Cap liquid-glass / glass-surface tokens (`tokens.css` + `index.css`).
abstract final class LiquidGlass {
  static const double blurSm = 16;
  static const double blurMd = 32;
  static const double blurLg = 40;
  static const double blurUltra = 64;

  static Color fill(BuildContext context, {LiquidGlassWeight weight = LiquidGlassWeight.regular}) {
    final light = MatteSurface.isLight(context);
    switch (weight) {
      case LiquidGlassWeight.thin:
        return light
            ? const Color.fromRGBO(255, 255, 255, 0.72)
            : const Color.fromRGBO(255, 255, 255, 0.03);
      case LiquidGlassWeight.regular:
        return light
            ? const Color.fromRGBO(248, 248, 250, 0.82)
            : const Color.fromRGBO(16, 16, 22, 0.55);
      case LiquidGlassWeight.thick:
        return light
            ? const Color.fromRGBO(255, 255, 255, 0.92)
            : const Color.fromRGBO(255, 255, 255, 0.14);
      case LiquidGlassWeight.modal:
        return light
            ? const Color.fromRGBO(255, 255, 255, 0.95)
            : const Color.fromRGBO(18, 18, 22, 0.92);
      case LiquidGlassWeight.frostPill:
        return light
            ? const Color.fromRGBO(255, 255, 255, 0.88)
            : const Color.fromRGBO(248, 248, 250, 0.14);
    }
  }

  static Color border(BuildContext context, {LiquidGlassWeight weight = LiquidGlassWeight.regular}) {
    final light = MatteSurface.isLight(context);
    if (light) return Colors.black.withAlpha(28);
    switch (weight) {
      case LiquidGlassWeight.thin:
        return NexusTheme.border;
      case LiquidGlassWeight.thick:
        return const Color.fromRGBO(255, 255, 255, 0.28);
      case LiquidGlassWeight.modal:
      case LiquidGlassWeight.frostPill:
        return const Color.fromRGBO(255, 255, 255, 0.22);
      case LiquidGlassWeight.regular:
        return const Color.fromRGBO(255, 255, 255, 0.18);
    }
  }

  static List<BoxShadow> shadows(BuildContext context, {bool floating = false}) {
    final light = MatteSurface.isLight(context);
    if (light) {
      return [
        BoxShadow(
          color: Colors.black.withAlpha(floating ? 28 : 18),
          blurRadius: floating ? 28 : 16,
          offset: Offset(0, floating ? 12 : 6),
        ),
        const BoxShadow(
          color: Color(0x66FFFFFF),
          blurRadius: 0,
          offset: Offset(0, 1),
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withAlpha(floating ? 160 : 100),
        blurRadius: floating ? 40 : 24,
        offset: Offset(0, floating ? 16 : 10),
      ),
      BoxShadow(
        color: Colors.white.withAlpha(28),
        blurRadius: 0,
        offset: const Offset(0, 1),
      ),
    ];
  }
}

enum LiquidGlassWeight { thin, regular, thick, modal, frostPill }

/// Cap `.liquid-glass-card` / `.glass-surface` — frosted panel with sheen.
class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
    this.weight = LiquidGlassWeight.regular,
    this.blur = LiquidGlass.blurMd,
    this.floating = false,
    this.clip = true,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final LiquidGlassWeight weight;
  final double blur;
  final bool floating;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final fill = LiquidGlass.fill(context, weight: weight);
    final border = LiquidGlass.border(context, weight: weight);
    final light = MatteSurface.isLight(context);

    Widget panel = Stack(
      children: [
        // Body fill
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: fill,
              border: Border.all(color: border),
              boxShadow: LiquidGlass.shadows(context, floating: floating),
            ),
          ),
        ),
        // Cap liquid-glass highlight sheen (top wash)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: light
                      ? [
                          Colors.white.withAlpha(120),
                          Colors.white.withAlpha(30),
                          Colors.transparent,
                        ]
                      : [
                          Colors.white.withAlpha(36),
                          Colors.white.withAlpha(10),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.35, 0.62],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ],
    );

    panel = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: panel,
    );

    if (!clip) return panel;
    return ClipRRect(borderRadius: radius, child: panel);
  }
}

/// Cap `.glass-pill` — frosted stadium chrome (top bar / chips).
class LiquidGlassPill extends StatelessWidget {
  const LiquidGlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.blur = LiquidGlass.blurSm,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final content = LiquidGlassPanel(
      borderRadius: 999,
      weight: LiquidGlassWeight.frostPill,
      blur: blur,
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// Cap `.modal-liquid-glass` sheet shell.
class LiquidGlassSheet extends StatelessWidget {
  const LiquidGlassSheet({
    super.key,
    required this.child,
    this.heightFactor = 0.88,
  });

  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * heightFactor;
    final light = MatteSurface.isLight(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: LiquidGlass.blurLg, sigmaY: LiquidGlass.blurLg),
        child: Container(
          height: h,
          decoration: BoxDecoration(
            gradient: light
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromRGBO(18, 18, 22, 0.94),
                      Color.fromRGBO(24, 24, 30, 0.90),
                    ],
                  ),
            color: light ? const Color.fromRGBO(255, 255, 255, 0.95) : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: light
                  ? Colors.black.withAlpha(18)
                  : Colors.white.withAlpha(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(light ? 40 : 140),
                blurRadius: 48,
                offset: const Offset(0, -8),
              ),
              BoxShadow(
                color: Colors.white.withAlpha(light ? 200 : 28),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MatteSurface.ink(context).withAlpha(60),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
