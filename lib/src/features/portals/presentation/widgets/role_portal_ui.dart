import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

class PortalHero extends StatelessWidget {
  const PortalHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final light = MatteSurface.isLight(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: light ? Colors.white.withAlpha(235) : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(SwipessTokens.radiusCard),
        border: Border.all(
          color: light ? Colors.black.withAlpha(18) : Colors.white.withAlpha(22),
        ),
        boxShadow: SwipessTokens.cardShadow(accent: accent, isLight: light),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withAlpha(light ? 24 : 34),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withAlpha(80)),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: SwipessTokens.kickerUppercase(
                    color: accent,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: SwipessTokens.displayItalic(
                    color: ink,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: SwipessTokens.bodyClean(
                    color: ink.withAlpha(155),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class PortalMetricCard extends StatelessWidget {
  const PortalMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final light = MatteSurface.isLight(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: light ? Colors.white : SwipessTokens.darkElevated,
            borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
            border: Border.all(
              color: light ? Colors.black.withAlpha(16) : Colors.white.withAlpha(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(28),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: ink.withAlpha(90),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: SwipessTokens.priceOversized(color: ink, fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwipessTokens.kickerUppercase(
                  color: ink.withAlpha(145),
                  fontSize: 9.5,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 5),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink.withAlpha(105),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PortalCard extends StatelessWidget {
  const PortalCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color? accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final light = MatteSurface.isLight(context);
    final border = accent?.withAlpha(80) ??
        (light ? Colors.black.withAlpha(16) : Colors.white.withAlpha(18));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: light ? Colors.white : SwipessTokens.darkElevated,
            borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
            border: Border.all(color: border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PortalStatusPill extends StatelessWidget {
  const PortalStatusPill({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: resolved.withAlpha(25),
        borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
        border: Border.all(color: resolved.withAlpha(90)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: resolved,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
      case 'accepted':
      case 'live':
      case 'available':
        return const Color(0xFF22C55E);
      case 'pending':
      case 'ringing':
      case 'in_progress':
      case 'reviewing':
        return const Color(0xFFF59E0B);
      case 'rejected':
      case 'declined':
      case 'cancelled':
      case 'missed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF818CF8);
    }
  }
}

class PortalSectionTitle extends StatelessWidget {
  const PortalSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: SwipessTokens.kickerUppercase(
                  color: ink.withAlpha(150),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: SwipessTokens.bodyClean(
                    color: ink.withAlpha(110),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class PortalPillButton extends StatelessWidget {
  const PortalPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = const Color(0xFF818CF8),
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final light = MatteSurface.isLight(context);
    final foreground = filled
        ? Colors.white
        : (light ? accent : (accent.computeLuminance() > .65 ? Colors.white : accent));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: filled ? accent : accent.withAlpha(light ? 18 : 25),
            borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
            border: Border.all(color: accent.withAlpha(filled ? 0 : 80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: onTap == null ? ink.withAlpha(70) : foreground),
              const SizedBox(width: 7),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: onTap == null ? ink.withAlpha(70) : foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PortalEmptyState extends StatelessWidget {
  const PortalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return PortalCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, color: ink.withAlpha(90), size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SwipessTokens.displayItalic(color: ink, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SwipessTokens.bodyClean(
                color: ink.withAlpha(125),
                fontSize: 12,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class PortalLoading extends StatelessWidget {
  const PortalLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
