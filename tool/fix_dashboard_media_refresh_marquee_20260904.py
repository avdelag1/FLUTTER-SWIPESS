from pathlib import Path


def load(path: str) -> str:
    return Path(path).read_text()


def save(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(path: str, old: str, new: str, label: str) -> None:
    text = load(path)
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'{label}: target not found in {path}')
    save(path, text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# 1) Dashboard Events = muted autoplay commercial reel.
#    Any manual listing Quick Filter play pauses it through the existing shared
#    playback coordinator. When that listing releases playback, Events resumes
#    the same controller/position and keeps advancing event-to-event.
# ---------------------------------------------------------------------------
events = 'lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart'
replace_once(
    events,
    '  bool _videoPreviewEnabled = false;\n',
    '  bool _videoPreviewEnabled = true;\n',
    'events autoplay default',
)
replace_once(
    events,
    """  void _resumeAfterListingPreview() {
    if (!_externallyPaused) return;
    _externallyPaused = false;
    // Never resume Events automatically; only the user's Play tap may start it.
  }
""",
    """  void _resumeAfterListingPreview() {
    if (!_externallyPaused) return;
    _externallyPaused = false;
    if (_canPlay) unawaited(_resumePlayback());
  }
""",
    'events resume after listing preview',
)
replace_once(
    events,
    """      if (value.position > Duration.zero && remainingMs <= 180) {
        _completionQueued = true;
        unawaited(controller.pause());
      }
""",
    """      if (value.position > Duration.zero && remainingMs <= 180) {
        _completionQueued = true;
        unawaited(_advance(1));
      }
""",
    'events completion advances',
)
replace_once(
    events,
    """    _switching = true;
    // Navigation is user-driven and the newly selected event stays paused.
    if (_videoPreviewEnabled && mounted) {
      setState(() => _videoPreviewEnabled = false);
    }
    try {
""",
    """    _switching = true;
    try {
""",
    'events user navigation remains live',
)


# ---------------------------------------------------------------------------
# 2) Pull-to-refresh = actual fresh dashboard data, not just invalidation.
#    Wait for every visible quick-filter family and Events before completing the
#    PWA refresh gesture, with a short minimum visible duration for clear UX.
# ---------------------------------------------------------------------------
refresh = 'lib/src/core/performance/app_refresh_service.dart'
text = load(refresh)
start = text.index('  static Future<void> refreshDashboardContainer(')
end = text.index('\n  static Future<void> refreshDashboardSilently', start)
new_refresh = """  static Future<void> refreshDashboardContainer(
    ProviderContainer container, {
    bool haptic = true,
  }) async {
    final startedAt = DateTime.now();
    if (haptic) AppHaptics.selection();

    const listingCategories = <String>[
      'property',
      'services',
      'yacht',
      'motorcycle',
      'bicycle',
    ];
    const peopleCategories = <String>['buyers', 'renters', 'seekers'];

    container.invalidate(newItemsCountProvider);
    container.invalidate(eventsListProvider);
    container.invalidate(dashboardVideoEventsProvider);
    container.invalidate(swipeListingsProvider);
    for (final category in listingCategories) {
      container.invalidate(quickFilterPreviewListingsProvider(category));
    }
    for (final category in peopleCategories) {
      container.invalidate(quickFilterPeoplePreviewProvider(category));
    }

    await Future.wait<void>([
      _safe(() => container.read(eventsListProvider.notifier).refresh()),
      _safe(() async {
        await container.read(newItemsCountProvider.future);
      }),
      _safe(() async {
        await container.read(dashboardVideoEventsProvider.future);
      }),
      for (final category in listingCategories)
        _safe(() async {
          await container.read(
            quickFilterPreviewListingsProvider(category).future,
          );
        }),
      for (final category in peopleCategories)
        _safe(() async {
          await container.read(
            quickFilterPeoplePreviewProvider(category).future,
          );
        }),
      _safe(() => AppPerformanceBootstrap.warmInteractiveSurfaces(container)),
    ]);

    const minimumVisible = Duration(milliseconds: 420);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minimumVisible) {
      await Future<void>.delayed(minimumVisible - elapsed);
    }
  }
"""
text = text[:start] + new_refresh + text[end:]
save(refresh, text)


# ---------------------------------------------------------------------------
# 3) Compact header AI prompts = smaller text + left-moving marquee instead of
#    ellipsis, so phone users can actually read the rotating suggestions.
# ---------------------------------------------------------------------------
glow = 'lib/src/core/widgets/glow_search_bar.dart'
replace_once(
    glow,
    """                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 380),
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: <Widget>[
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              child: Text(
                                displayHint,
                                key: ValueKey<String>(displayHint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink.withAlpha(isLight ? 190 : 225),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
""",
    """                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final promptStyle = GoogleFonts.plusJakartaSans(
                                  color: ink.withAlpha(isLight ? 190 : 225),
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.compactHeader ? 11.0 : 14.0,
                                );
                                final painter = TextPainter(
                                  text: TextSpan(
                                    text: displayHint,
                                    style: promptStyle,
                                  ),
                                  maxLines: 1,
                                  textDirection: Directionality.of(context),
                                )..layout();
                                final travel = math.max(
                                  0.0,
                                  painter.width - constraints.maxWidth + 12,
                                );
                                final durationMs = (2800 + travel * 18)
                                    .round()
                                    .clamp(3200, 6500)
                                    .toInt();
                                return ClipRect(
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey<String>(displayHint),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: Duration(milliseconds: durationMs),
                                    curve: Curves.linear,
                                    builder: (context, progress, child) =>
                                        Transform.translate(
                                          offset: Offset(-travel * progress, 0),
                                          child: child,
                                        ),
                                    child: Text(
                                      displayHint,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                      style: promptStyle,
                                    ),
                                  ),
                                );
                              },
                            ),
""",
    'compact AI prompt marquee',
)


# ---------------------------------------------------------------------------
# 4) Header menu must not hide its own header/burger while PopupMenuRoute is
#    open. Keep the existing full-screen route protection, but explicitly mark
#    the small header menu as an allowed overlay.
# ---------------------------------------------------------------------------
provider = Path('lib/src/core/providers/header_menu_open_provider.dart')
provider.write_text(
    "import 'package:flutter_riverpod/legacy.dart';\n\n"
    "final headerMenuOpenProvider = StateProvider<bool>((ref) => false);\n"
)

topbar = 'lib/src/core/widgets/app_top_bar.dart'
text = load(topbar)
import_anchor = "import 'package:flutter_swipes/src/core/providers/search_bar_slot_provider.dart';\n"
provider_import = "import 'package:flutter_swipes/src/core/providers/header_menu_open_provider.dart';\n"
if provider_import not in text:
    if import_anchor not in text:
        raise SystemExit('header menu provider import anchor not found')
    text = text.replace(import_anchor, import_anchor + provider_import, 1)
old = '          onOpened: AppHaptics.light,\n          onSelected: (value) {\n            AppHaptics.selection();\n'
new = """          onOpened: () {
            ref.read(headerMenuOpenProvider.notifier).state = true;
            AppHaptics.light();
          },
          onCanceled: () {
            ref.read(headerMenuOpenProvider.notifier).state = false;
          },
          onSelected: (value) {
            ref.read(headerMenuOpenProvider.notifier).state = false;
            AppHaptics.selection();
"""
if new not in text:
    if old not in text:
        raise SystemExit('header PopupMenu lifecycle target not found')
    text = text.replace(old, new, 1)
save(topbar, text)

shell = 'lib/src/features/dashboard/presentation/screens/dashboard_shell.dart'
text = load(shell)
shell_import_anchor = "import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';\n"
shell_provider_import = "import 'package:flutter_swipes/src/core/providers/header_menu_open_provider.dart';\n"
if shell_provider_import not in text:
    if shell_import_anchor not in text:
        raise SystemExit('dashboard shell provider import anchor not found')
    text = text.replace(
        shell_import_anchor,
        shell_import_anchor + shell_provider_import,
        1,
    )
old = """    final shellRouteIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    // The provider is the single source of truth for the real app header/dock.
"""
new = """    final shellRouteIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final headerMenuOpen = ref.watch(headerMenuOpenProvider);
    // The provider is the single source of truth for the real app header/dock.
"""
if new not in text:
    if old not in text:
        raise SystemExit('dashboard shell menu state target not found')
    text = text.replace(old, new, 1)
old = '    final persistentChromeVisible = chromeOpacity > 0.01 && shellRouteIsCurrent;\n'
new = """    final persistentChromeVisible =
        chromeOpacity > 0.01 && (shellRouteIsCurrent || headerMenuOpen);
"""
if new not in text:
    if old not in text:
        raise SystemExit('dashboard shell chrome visibility target not found')
    text = text.replace(old, new, 1)
save(shell, text)

# Keep source-level regression test aligned with the menu exception.
test = 'test/persistent_chrome_overlap_guard_test.dart'
if Path(test).exists():
    text = load(test)
    text = text.replace(
        "contains('chromeOpacity > 0.01 && shellRouteIsCurrent')",
        "contains('chromeOpacity > 0.01 && (shellRouteIsCurrent || headerMenuOpen)')",
    )
    save(test, text)


# ---------------------------------------------------------------------------
# 5) Explicit web crop/trim protection. KEEP FULL VIDEO is still the safest
#    path because it never rewrites frames. If the user explicitly edits on web,
#    count genuine decoded frames and reject a catastrophically sparse export
#    instead of publishing another fake-30fps/choppy file.
# ---------------------------------------------------------------------------
recut = 'lib/src/features/camera/data/video_recut_v3_html.dart'
replace_once(
    recut,
    """  JSObject? mediaElementSource;

  try {
""",
    """  JSObject? mediaElementSource;
  var presentedFrames = 0;
  var usesDecodedFrameClock = false;

  try {
""",
    'web edit frame guard state',
)
replace_once(
    recut,
    """    if (videoJs.hasProperty('requestVideoFrameCallback'.toJS).toDart) {
      late JSFunction onVideoFrame;
      onVideoFrame = ((JSAny? _, JSAny? __) {
        if (video == null) return;
        paintFrame();
""",
    """    if (videoJs.hasProperty('requestVideoFrameCallback'.toJS).toDart) {
      usesDecodedFrameClock = true;
      late JSFunction onVideoFrame;
      onVideoFrame = ((JSAny? _, JSAny? __) {
        if (video == null) return;
        paintFrame();
        presentedFrames += 1;
""",
    'web edit count genuine frames',
)
replace_once(
    recut,
    """    if (chunks.isEmpty)
      throw StateError('No optimized video data was produced.');

    final outputMime = selectedMime.contains('mp4')
""",
    """    if (chunks.isEmpty)
      throw StateError('No optimized video data was produced.');

    if (usesDecodedFrameClock && cutDuration >= 1.5) {
      final realFps = presentedFrames / cutDuration;
      if (realFps < 12) {
        throw StateError(
          'This browser could not preserve smooth motion for this edit. '
          'Choose KEEP FULL VIDEO or retry the edit.',
        );
      }
    }

    final outputMime = selectedMime.contains('mp4')
""",
    'web edit reject sparse export',
)

print('SWIPESS dashboard media/refresh/menu/video edit patch applied.')
