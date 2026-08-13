import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `AmbientPageBackground` — monochrome tonal wells, no colorful orbs.
class AmbientPageBackground extends StatelessWidget {
  const AmbientPageBackground({
    super.key,
    required this.child,
    this.fill = false,
    this.padding,
    this.subtle = false,
  });

  final Widget child;
  final bool fill;
  final EdgeInsetsGeometry? padding;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    final body =
        padding == null ? child : Padding(padding: padding!, child: child);
    return ColoredBox(
      color: AppTheme.canvasFor(isLight: isLight),
      child: Stack(
        fit: fill ? StackFit.expand : StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: subtle ? 0.9 : 1,
                child: _AmbientWells(isLight: isLight),
              ),
            ),
          ),
          fill ? Positioned.fill(child: body) : body,
        ],
      ),
    );
  }
}

class _AmbientWells extends StatelessWidget {
  const _AmbientWells({required this.isLight});
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final topWash = isLight
        ? const Color(0x8CFFFFFF) // ~0.55 white
        : const Color(0x09FFFFFF); // Cap ~0.035
    final bottomWell = isLight
        ? const Color(0x0A000000) // ~0.04 black
        : const Color(0x08FFFFFF); // ~0.03 white

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topWash, const Color(0x00000000)],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: const Offset(0, 80),
            child: Container(
              width: 520,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [bottomWell, const Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared inner-page chrome: ambient canvas + safe padded column.
class NeoNaivePage extends StatelessWidget {
  const NeoNaivePage({
    super.key,
    required this.child,
    this.scrollable = true,
  });

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: scrollable
            ? SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, top + 12, 20, bottom + 40),
                child: child,
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(20, top + 12, 20, bottom + 24),
                child: child,
              ),
      ),
    );
  }
}

/// Cap `neo-naive-card` / glass panel used on inner pages.
class NeoNaiveCard extends StatelessWidget {
  const NeoNaiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.inkStamp = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool inkStamp;

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: inkStamp
          ? AppTheme.neoNaiveCard
          : AppTheme.softSurfaceCard(isLight: isLight),
      child: child,
    );
  }
}

/// Cap `neo-naive-group` — stacked rows with soft hairline dividers.
class NeoNaiveGroup extends StatelessWidget {
  const NeoNaiveGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hairline = MatteSurface.hairline(context);
    return Container(
      width: double.infinity,
      decoration: AppTheme.softSurfaceCard(
        isLight: MatteSurface.isLight(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: hairline),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Black canvas + ambient wells. Drop-in for inner Cap pages (not gate/swipe).
class NeoNaiveScaffold extends StatelessWidget {
  const NeoNaiveScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
  });

  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemFor(isLight: isLight),
      child: Scaffold(
        backgroundColor: AppTheme.canvasFor(isLight: isLight),
        floatingActionButton: floatingActionButton,
        body: AmbientPageBackground(fill: true, child: body),
      ),
    );
  }
}

/// Stadium filter pill — Cap `neo-naive-pill`, never Material [ChoiceChip].
class NeoNaiveChip extends StatelessWidget {
  const NeoNaiveChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor = AppTheme.brandPrimary,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color selectedColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final hairline = MatteSurface.hairline(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? selectedColor : hairline,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : ink),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : ink,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cap AtmosphericLayer shim — same ambient wells as page background.
class AtmosphericLayer extends StatelessWidget {
  const AtmosphericLayer({
    super.key,
    this.opacity = 1,
    this.variant = AtmosphericVariant.defaultTone,
  });

  final double opacity;
  final AtmosphericVariant variant;

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    Color? tint;
    switch (variant) {
      case AtmosphericVariant.indigo:
        tint = NexusTheme.indigo.withAlpha(28);
      case AtmosphericVariant.rose:
        tint = NexusTheme.rose.withAlpha(28);
      case AtmosphericVariant.primary:
        tint = AppTheme.brandPrimary.withAlpha(22);
      case AtmosphericVariant.defaultTone:
      case AtmosphericVariant.swipes:
        tint = null;
    }
    return IgnorePointer(
      child: Opacity(
        opacity: opacity < 0.15 ? 0.85 : opacity.clamp(0.0, 1.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AmbientWells(isLight: isLight),
            if (tint != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.7, -0.6),
                    radius: 1.1,
                    colors: [tint, const Color(0x00000000)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum AtmosphericVariant { defaultTone, primary, indigo, rose, swipes }
