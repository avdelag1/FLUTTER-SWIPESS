import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/bulk_selection_bar.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern listing/profile tile used by the Likes page.
class PremiumLikedCard extends StatelessWidget {
  const PremiumLikedCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.onMessage,
    required this.onView,
    required this.onRemove,
    this.priceLabel,
    this.bedsLabel,
    this.description,
    this.verified = false,
    this.isProfile = false,
    this.selectionMode = false,
    this.selected = false,
    this.onSelect,
  });

  final String? imageUrl;
  final String title;
  final String subtitle;
  final String category;
  final VoidCallback onMessage;
  final VoidCallback onView;
  final VoidCallback onRemove;
  final String? priceLabel;
  final String? bedsLabel;
  final String? description;
  final bool verified;
  final bool isProfile;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelect;

  static const accent = Color(0xFF4C8DFF);

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: const Color(0xFF12161D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? accent.withAlpha(175) : Colors.white.withAlpha(18),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? accent.withAlpha(34)
                : Colors.black.withAlpha(65),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AbsorbPointer(
        absorbing: selectionMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 184,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      errorBuilder: (_, _, _) => _fallback(),
                    )
                  else
                    _fallback(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x08000000),
                          Color(0x22000000),
                          Color(0xD9000000),
                        ],
                        stops: [0, .55, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _GlassLabel(label: category.toUpperCase()),
                  ),
                  if (!selectionMode)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _CircleAction(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Remove from likes',
                        onTap: () {
                          AppHaptics.light();
                          onRemove();
                        },
                      ),
                    ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 13,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        if (subtitle.trim().isNotEmpty) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: accent,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withAlpha(220),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (bedsLabel != null)
                        _SpecChip(icon: Icons.bed_outlined, label: bedsLabel!),
                      if (priceLabel != null)
                        _SpecChip(
                          icon: Icons.payments_outlined,
                          label: priceLabel!,
                          highlighted: true,
                        ),
                      if (verified)
                        const _SpecChip(
                          icon: Icons.verified_rounded,
                          label: 'Verified',
                          highlighted: true,
                        ),
                    ],
                  ),
                  if (description?.trim().isNotEmpty == true) ...[
                    SizedBox(height: 9),
                    Text(
                      description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(170),
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Message',
                          primary: true,
                          onTap: () {
                            AppHaptics.medium();
                            onMessage();
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.visibility_outlined,
                          label: 'View',
                          onTap: () {
                            AppHaptics.selection();
                            onView();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!selectionMode && onSelect == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: selectionMode ? onSelect : null,
      onLongPress: onSelect,
      child: Stack(
        children: [
          card,
          if (selectionMode)
            Positioned(
              top: 12,
              right: 12,
              child: SelectionBadge(selected: selected, accent: accent),
            ),
        ],
      ),
    );
  }

  Widget _fallback() {
    if (isProfile) {
      return FunAvatar(
        seed: title,
        size: 192,
        borderRadius: BorderRadius.zero,
        semanticLabel: '$title temporary profile avatar',
      );
    }
    return const ColoredBox(
      color: Color(0xFF1B2028),
      child: Icon(Icons.home_outlined, size: 44, color: Colors.white38),
    );
  }
}

class _GlassLabel extends StatelessWidget {
  const _GlassLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(115),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(120),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(35)),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });
  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? PremiumLikedCard.accent : Colors.white70;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? color.withAlpha(22) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: primary
              ? PremiumLikedCard.accent
              : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: primary
                ? PremiumLikedCard.accent
                : Colors.white.withAlpha(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
