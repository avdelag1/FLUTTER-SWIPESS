import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_controls.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_layout.dart';

enum CapEmptyVariant { likes, messages, search, generic }

/// Branded empty state used anywhere the app has nothing meaningful to show.
class CapEmptyState extends StatelessWidget {
  const CapEmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.variant = CapEmptyVariant.generic,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final CapEmptyVariant variant;

  IconData get _heroIcon => switch (variant) {
    CapEmptyVariant.likes => Icons.favorite_border_rounded,
    CapEmptyVariant.messages => Icons.chat_bubble_outline_rounded,
    CapEmptyVariant.search => Icons.search_rounded,
    CapEmptyVariant.generic => icon,
  };

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final accent = SwipessTokens.brandPink;
    final narrow = SwipessResponsive.isNarrow(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 12 : 20,
            vertical: narrow ? 26 : 38,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: narrow ? 64 : 72,
                height: narrow ? 64 : 72,
                decoration: BoxDecoration(
                  color: accent.withAlpha(MatteSurface.isLight(context) ? 18 : 24),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: MatteSurface.hairline(context)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withAlpha(24),
                      blurRadius: 28,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Icon(_heroIcon, color: accent, size: narrow ? 29 : 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: SwipessTokens.displayItalic(
                  color: ink,
                  fontSize: narrow ? 20 : 22,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: SwipessTokens.bodyClean(
                    color: muted.withAlpha(MatteSurface.isLight(context) ? 210 : 175),
                    fontSize: 13,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: SwipessButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    accentColor: accent,
                    height: SwipessTokens.heightCompactCTA,
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

/// Branded progress instead of a lonely platform spinner.
class CapLoadingState extends StatelessWidget {
  const CapLoadingState({
    super.key,
    this.label = 'Loading',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 22 : 28,
              height: compact ? 22 : 28,
              child: const CircularProgressIndicator(
                strokeWidth: 2.4,
                color: SwipessTokens.brandPink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: SwipessTokens.meta(color: ink.withAlpha(175)),
            ),
          ],
        ),
      ),
    );
  }
}

class CapErrorState extends StatelessWidget {
  const CapErrorState({
    super.key,
    required this.title,
    required this.description,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String description;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return CapEmptyState(
      title: title,
      description: description,
      icon: Icons.refresh_rounded,
      actionLabel: onRetry == null ? null : retryLabel,
      onAction: onRetry,
    );
  }
}

class CapPageHeader extends StatelessWidget {
  const CapPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Row(
      children: [
        if (onBack != null) ...[
          SwipessIconAction(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: onBack,
            tooltip: 'Back',
            size: 42,
            iconSize: 17,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwipessResponsiveTitle(
                text: title,
                style: SwipessTokens.displayItalic(color: ink, fontSize: 26),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SwipessTokens.bodyClean(color: muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
