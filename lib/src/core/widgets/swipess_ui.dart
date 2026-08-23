import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Master Circular Icon Tile with soft radial illumination
class SwipessIconTile extends StatelessWidget {
  const SwipessIconTile({
    super.key,
    required this.icon,
    required this.accentColor,
    this.size = 44.0,
    this.iconSize = 22.0,
    this.isLight = false,
  });

  final IconData icon;
  final Color accentColor;
  final double size;
  final double iconSize;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withAlpha(isLight ? 35 : 45),
        border: Border.all(
          color: accentColor.withAlpha(isLight ? 70 : 110),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(isLight ? 20 : 50),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: isLight ? accentColor : Colors.white,
      ),
    );
  }
}

/// Tactile Primary CTA with subtle scale press effect (0.98)
class SwipessPrimaryCTA extends StatefulWidget {
  const SwipessPrimaryCTA({
    super.key,
    required this.label,
    required this.onTap,
    this.accentColor = SwipessTokens.brandOrange,
    this.height = SwipessTokens.heightCTA,
    this.isLoading = false,
    this.isDisabled = false,
    this.gradient,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final Color accentColor;
  final double height;
  final bool isLoading;
  final bool isDisabled;
  final Gradient? gradient;
  final IconData? icon;

  @override
  State<SwipessPrimaryCTA> createState() => _SwipessPrimaryCTAState();
}

class _SwipessPrimaryCTAState extends State<SwipessPrimaryCTA> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active =
        !widget.isDisabled && !widget.isLoading && widget.onTap != null;

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTap: active
          ? () {
              AppHaptics.medium();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.gradient == null
                ? (active ? widget.accentColor : Colors.white.withAlpha(20))
                : null,
            gradient: active ? widget.gradient : null,
            borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: widget.accentColor.withAlpha(90),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        color: active ? Colors.white : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Integrated Tier Badge physically connected to card headers
class SwipessTierBadge extends StatelessWidget {
  const SwipessTierBadge({
    super.key,
    required this.label,
    required this.accentColor,
  });

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(45),
        borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
        border: Border.all(color: accentColor.withAlpha(120), width: 1.0),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: accentColor,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Master Tier Card Container for Commerce (Tokens, Premium Plans)
class SwipessTierCard extends StatelessWidget {
  const SwipessTierCard({
    super.key,
    required this.child,
    required this.accentColor,
    this.badgeLabel,
    this.isHighlighted = false,
    this.isLight = false,
    this.onTap,
  });

  final Widget child;
  final Color accentColor;
  final String? badgeLabel;
  final bool isHighlighted;
  final bool isLight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isLight
        ? (isHighlighted
              ? accentColor.withAlpha(12)
              : SwipessTokens.lightElevated)
        : (isHighlighted
              ? accentColor.withAlpha(22)
              : SwipessTokens.darkElevated);

    final border = isHighlighted
        ? accentColor.withAlpha(isLight ? 120 : 160)
        : (isLight ? SwipessTokens.lightBorder : SwipessTokens.darkBorder);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: SwipessTokens.paddingCard,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(SwipessTokens.radiusCard),
              border: Border.all(
                color: border,
                width: isHighlighted ? 1.8 : 1.0,
              ),
              boxShadow: SwipessTokens.cardShadow(
                accent: isHighlighted ? accentColor : Colors.black,
                isLight: isLight,
              ),
            ),
            child: child,
          ),
        ),
        if (badgeLabel != null)
          Positioned(
            top: -12,
            right: 20,
            child: SwipessTierBadge(
              label: badgeLabel!,
              accentColor: accentColor,
            ),
          ),
      ],
    );
  }
}

/// Reusable Service Action Card (Video Call, WhatsApp, etc.)
class SwipessServiceActionCard extends StatelessWidget {
  const SwipessServiceActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.statusPillLabel,
    this.statusPillColor = Colors.green,
    required this.onTap,
    this.isLight = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? statusPillLabel;
  final Color statusPillColor;
  final VoidCallback onTap;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return SwipessTierCard(
      accentColor: accentColor,
      isLight: isLight,
      onTap: onTap,
      child: Row(
        children: [
          SwipessIconTile(
            icon: icon,
            accentColor: accentColor,
            size: 48,
            iconSize: 24,
            isLight: isLight,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: SwipessTokens.displayItalic(
                    color: isLight ? Colors.black : Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: SwipessTokens.bodyClean(
                    color: isLight ? Colors.black54 : Colors.white,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (statusPillLabel != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusPillColor.withAlpha(30),
                borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
                border: Border.all(
                  color: statusPillColor.withAlpha(100),
                  width: 1,
                ),
              ),
              child: Text(
                statusPillLabel!.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: statusPillColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable Metric Stat Card for Listing Control
class SwipessStatCard extends StatelessWidget {
  const SwipessStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.isLight = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height <= 900;
    final background = isLight
        ? SwipessTokens.lightElevated
        : SwipessTokens.darkElevated;
    final border = isLight
        ? SwipessTokens.lightBorder
        : SwipessTokens.darkBorder;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
          border: Border.all(color: border),
          boxShadow: SwipessTokens.cardShadow(isLight: isLight),
        ),
        child: Row(
          children: [
            SwipessIconTile(
              icon: icon,
              accentColor: accentColor,
              size: 22,
              iconSize: 12,
              isLight: isLight,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: SwipessTokens.kickerUppercase(
                      color: isLight ? Colors.black54 : Colors.white,
                      fontSize: 7.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle.toUpperCase(),
                    style: SwipessTokens.kickerUppercase(
                      color: isLight ? Colors.black38 : Colors.white,
                      fontSize: 6.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: SwipessTokens.priceOversized(
                  color: isLight ? Colors.black : Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
        border: Border.all(color: border),
        boxShadow: SwipessTokens.cardShadow(isLight: isLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: SwipessTokens.kickerUppercase(
                    color: isLight ? Colors.black54 : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SwipessIconTile(
                icon: icon,
                accentColor: accentColor,
                size: 32,
                iconSize: 16,
                isLight: isLight,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: SwipessTokens.priceOversized(
              color: isLight ? Colors.black : Colors.white,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle.toUpperCase(),
            style: SwipessTokens.kickerUppercase(
              color: isLight ? Colors.black38 : Colors.white,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable Chunky Profile/Dashboard Control Tile
class SwipessDashboardTile extends StatefulWidget {
  const SwipessDashboardTile({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.height = 72.0,
    this.isFullWidth = false,
  });

  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final double height;
  final bool isFullWidth;

  @override
  State<SwipessDashboardTile> createState() => _SwipessDashboardTileState();
}

class _SwipessDashboardTileState extends State<SwipessDashboardTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        AppHaptics.medium();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: widget.isFullWidth
                ? MainAxisAlignment.center
                : MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 22, color: Colors.white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.title.toUpperCase(),
                  style: SwipessTokens.displayItalic(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
