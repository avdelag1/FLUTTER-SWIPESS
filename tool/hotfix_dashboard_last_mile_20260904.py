from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Missing target for {label}: {path}")
    p.write_text(text.replace(old, new, 1))


# 1) Listing quick filters: once a live preview has resolved, use the editorial
# category pool only when there is no real inventory. Fallback media has no
# listing id, so tapping it opens the category rather than a fake card.
replace_once(
    "lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart",
    """        : isListingPreviewQuickFilter
        ? (previewResolved ? listingPreviewMedia : const <String>[])
        : BentoMediaPools.forId(item.id);""",
    """        : isListingPreviewQuickFilter
        ? (previewResolved
              ? (listingPreviewMedia.isNotEmpty
                    ? listingPreviewMedia
                    : BentoMediaPools.forId(item.id))
              : const <String>[])
        : BentoMediaPools.forId(item.id);""",
    "listing quick-filter visual fallback",
)

# 2) Human-readable continuous AI ticker. Current and next prompt travel as one
# strip. At the end, the next prompt is already exactly where the current prompt
# started, so the index handoff is visually seamless.
replace_once(
    "lib/src/core/widgets/glow_search_bar.dart",
    "const Duration(milliseconds: 5200)",
    "const Duration(milliseconds: 8300)",
    "prompt cadence",
)

old_marquee = """                                  final painter = TextPainter(
                                    text: TextSpan(text: displayHint, style: promptStyle),
                                    maxLines: 1,
                                    textDirection: Directionality.of(context),
                                  )..layout();
                                  final travel = math.max(
                                    painter.width + 18,
                                    constraints.maxWidth + 18,
                                  );
                                  return ClipRect(
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey<String>(displayHint),
                                      tween: Tween<double>(begin: 0, end: 1),
                                      duration: const Duration(milliseconds: 5000),
                                      curve: Curves.linear,
                                      builder: (context, progress, child) {
                                        return Transform.translate(
                                          offset: Offset(-travel * progress, 0),
                                          child: child,
                                        );
                                      },
                                      child: Text(
                                        displayHint,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: promptStyle,
                                      ),
                                    ),
                                  );"""

new_marquee = """                                  final nextHint = prompts[
                                    (_promptIndex + 1) % prompts.length
                                  ];
                                  const separator = '      •      ';
                                  final currentRun = '$displayHint$separator';
                                  final tickerText = '$currentRun$nextHint';
                                  final painter = TextPainter(
                                    text: TextSpan(text: currentRun, style: promptStyle),
                                    maxLines: 1,
                                    textDirection: Directionality.of(context),
                                  )..layout();
                                  final travel = painter.width;
                                  return ClipRect(
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey<String>(displayHint),
                                      tween: Tween<double>(begin: 0, end: 1),
                                      duration: const Duration(milliseconds: 8200),
                                      curve: Curves.linear,
                                      builder: (context, progress, child) {
                                        return Transform.translate(
                                          offset: Offset(-travel * progress, 0),
                                          child: child,
                                        );
                                      },
                                      child: Text(
                                        tickerText,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: promptStyle,
                                      ),
                                    ),
                                  );"""
replace_once(
    "lib/src/core/widgets/glow_search_bar.dart",
    old_marquee,
    new_marquee,
    "continuous AI marquee",
)

print("Dashboard last-mile patch applied.")
