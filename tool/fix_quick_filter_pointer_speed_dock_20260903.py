from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing patch target: {label}")
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, repl: str, label: str, flags: int = 0) -> str:
    updated, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"missing/ambiguous patch target: {label} ({count})")
    return updated


# ---------------------------------------------------------------------------
# Dependency: the dashboard web video is an HtmlElementView. A normal Flutter
# GestureDetector drawn around/over it is not enough on web because the native
# element can swallow the pointer before Flutter receives it. pointer_interceptor
# is the Flutter-maintained solution for exactly this platform-view problem.
# ---------------------------------------------------------------------------
p = "pubspec.yaml"
s = read(p)
if "  pointer_interceptor:" not in s:
    s = replace_once(
        s,
        "  video_player: ^2.10.1\n",
        "  video_player: ^2.10.1\n  pointer_interceptor: ^0.10.1+2\n",
        "pointer interceptor dependency",
    )
write(p, s)

# ---------------------------------------------------------------------------
# Quick filters: dedicated interaction overlay ABOVE the media, platform-view
# interception for web video, faster controlled warmup, and no dead edge taps.
# ---------------------------------------------------------------------------
p = "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart"
s = read(p)
if "package:pointer_interceptor/pointer_interceptor.dart" not in s:
    s = replace_once(
        s,
        "import 'package:video_player/video_player.dart';\n",
        "import 'package:video_player/video_player.dart';\n"
        "import 'package:pointer_interceptor/pointer_interceptor.dart';\n",
        "pointer interceptor import",
    )

s = replace_once(
    s,
    "  static int get maxActive => kIsWeb ? 1 : 2;",
    "  // Keep two listing videos warm on web (plus Events' independent player)\n"
    "  // and three on native. One warm slot made whichever card lost the race\n"
    "  // feel cold even though its poster was already visible.\n"
    "  static int get maxActive => kIsWeb ? 2 : 3;",
    "warm video budget",
)

s = replace_once(
    s,
    "  double get _previewWarmupThreshold => kIsWeb ? 0.12 : 0.10;",
    "  // Start warming as soon as a meaningful slice of the card is visible.\n"
    "  // Initialization stays paused/muted, so this improves first-play latency\n"
    "  // without turning the dashboard into a wall of playing decoders.\n"
    "  double get _previewWarmupThreshold => kIsWeb ? 0.06 : 0.05;",
    "warmup visibility threshold",
)

s = replace_once(
    s,
    "    final delay = Duration(\n      milliseconds: (kIsWeb ? 24 : 12) + stagger * (kIsWeb ? 22 : 12),\n    );",
    "    final delay = Duration(\n"
    "      milliseconds: stagger * (kIsWeb ? 8 : 5),\n"
    "    );",
    "warmup stagger",
)

old_advance = """  void _advance(int delta) {
    if (_sources.length <= 1 || !mounted || !_routeActive) return;
    setState(() {
      _index = (_index + delta) % _sources.length;
      if (_index < 0) _index += _sources.length;
      _userPaused = true;
      _manualPlaybackStarted = false;
      _reportedVideoTurnComplete = false;
    });
    _disposeVideo();
    _scheduleVisibilityCheck();
  }
"""
new_advance = """  void _advance(int delta) {
    if (_sources.length <= 1 || !mounted || !_routeActive) return;
    setState(() {
      _index = (_index + delta) % _sources.length;
      if (_index < 0) _index += _sources.length;
      _userPaused = true;
      _manualPlaybackStarted = false;
      _reportedVideoTurnComplete = false;
    });
    _disposeVideo();

    // Re-evaluate immediately after a manual edge tap. If the newly selected
    // item is a video, start its paused initialization on the next frame rather
    // than waiting for another scroll/visibility event to happen by chance.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_routeActive) return;
      _scheduleVisibilityCheck();
      if (_visibleFraction >= _previewWarmupThreshold) {
        _schedulePreviewWarmup();
      }
    });
  }
"""
s = replace_once(s, old_advance, new_advance, "advance immediate warmup")

# Replace the parent GestureDetector. On web, a video_player HtmlElementView can
# consume taps before a parent Flutter detector sees them. The new AnimatedSwitcher
# is pointer-inert and a separate PointerInterceptor + three explicit hit zones
# is painted above it.
old_media_block_pattern = r'''        Positioned\.fill\(\n          child: GestureDetector\(\n            behavior: HitTestBehavior\.opaque,\n            onTapUp: \(details\) \{.*?            child: AnimatedSwitcher\(\n              duration: Duration\(milliseconds: kIsWeb \? 80 : 110\),\n              child: KeyedSubtree\(\n                key: ValueKey\('\$\{_videoEnabled \? 'video' : 'still'\}:\$current'\),\n                child: _buildMedia\(current\),\n              \),\n            \),\n          \),\n        \),'''
new_media_block = r'''        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: kIsWeb ? 55 : 70),
              child: KeyedSubtree(
                key: ValueKey('${_videoEnabled ? 'video' : 'still'}:$current'),
                child: _buildMedia(current),
              ),
            ),
          ),
        ),

        // IMPORTANT: this interaction surface is a sibling painted ABOVE the
        // movie, not a parent wrapping it. Web video_player renders an
        // HtmlElementView which can swallow taps from ordinary Flutter widgets.
        // PointerInterceptor places an empty web platform view between our hit
        // zones and the movie so Flutter reliably receives every tap.
        Positioned.fill(
          child: PointerInterceptor(
            intercepting: kIsWeb && _isKnownVideoUrl(current),
            child: Row(
              children: [
                Expanded(
                  flex: 30,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selection();
                      if (_sources.length > 1) {
                        _advance(-1);
                      } else {
                        widget.onOpen?.call(_listingIdForUrl(current));
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  flex: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.light();
                      // Center always opens the exact listing currently shown,
                      // regardless of whether its primary source is photo/video.
                      widget.onOpen?.call(_listingIdForUrl(current));
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  flex: 30,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selection();
                      if (_sources.length > 1) {
                        _advance(1);
                      } else {
                        widget.onOpen?.call(_listingIdForUrl(current));
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),'''
s = sub_once(
    s,
    old_media_block_pattern,
    new_media_block,
    "platform-safe quick filter hit zones",
    flags=re.S,
)

# Regression guards: the prior live/cold controller handoff must stay intact.
for needle, label in [
    ("preparation: preparation", "cold controller handoff"),
    ("controller: existing", "playing controller handoff"),
    ("_listingIdForUrl(current)", "exact listing identity"),
]:
    if needle not in s:
        raise SystemExit(f"regression guard failed: {label}")
write(p, s)

# ---------------------------------------------------------------------------
# Bottom dock: user asked for a slightly shorter but thicker pill. Keep 40px
# buttons for reliable taps, narrow only the visible viewport so scrolling is
# still playful, and increase the glass body thickness by 2px.
# ---------------------------------------------------------------------------
p = "lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart"
s = read(p)
s = replace_once(
    s,
    "constraints: const BoxConstraints(maxWidth: 342),",
    "constraints: const BoxConstraints(maxWidth: 326),",
    "dock shorter width",
)
s = replace_once(
    s,
    "                height: 46,\n                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),",
    "                height: 48,\n                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),",
    "dock thicker body",
)
write(p, s)
