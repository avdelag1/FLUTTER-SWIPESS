import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `AmbientPageBackground` — monochrome tonal wells, no colorful orbs.
class AmbientPageBackground extends StatelessWidget {
  const AmbientPageBackground({
    super.key,
    required this.child,
    this.fill = false,
    this.padding,
  });

  final Widget child;
  final bool fill;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final body = padding == null ? child : Padding(padding: padding!, child: child);
    return ColoredBox(
      color: AppTheme.dashBg,
      child: Stack(
        fit: fill ? StackFit.expand : StackFit.passthrough,
        children: [
          const Positioned.fill(child: IgnorePointer(child: _AmbientWells())),
          fill ? Positioned.fill(child: body) : body,
        ],
      ),
    );
  }
}

class _AmbientWells extends StatelessWidget {
  const _AmbientWells();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x09FFFFFF), Color(0x00000000)],
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x08FFFFFF), Color(0x00000000)],
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
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: inkStamp ? AppTheme.neoNaiveCard : AppTheme.glassCard,
      child: child,
    );
  }
}

/// Cap `neo-naive-group` — stacked rows with hairline dividers.
class NeoNaiveGroup extends StatelessWidget {
  const NeoNaiveGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.neoNaiveCard,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: Colors.transparent),
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
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: AmbientPageBackground(fill: true, child: body),
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
            color: selected ? selectedColor : Colors.white,
            width: 1.5,
          ),
          boxShadow: const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
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
