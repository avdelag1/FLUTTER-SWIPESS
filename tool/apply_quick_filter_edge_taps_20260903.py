from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def widen_three_tap_zones(block: str, label: str) -> str:
    matches = list(re.finditer(r"flex: (30|40),", block))
    if len(matches) != 3:
        raise SystemExit(f"{label}: expected exactly 3 tap-zone flexes, found {len(matches)}")
    desired = iter((40, 20, 40))
    return re.sub(
        r"flex: (30|40),",
        lambda _: f"flex: {next(desired)},",
        block,
        count=3,
    )


# ---------------------------------------------------------------------------
# Generic listing / people quick filters
# ---------------------------------------------------------------------------
quick_path = ROOT / "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart"
quick = quick_path.read_text()

quick = replace_once(
    quick,
    """            intercepting:\n                kIsWeb && (_isKnownVideoUrl(current) || _webPointerShieldHold),""",
    """            // On web/PWA the video element is a platform view. Keep the\n            // interceptor active for every photo/video state so the exact same\n            // left/center/right tap contract never disappears while media swaps.\n            intercepting: kIsWeb,""",
    "quick-filter permanent pointer shield",
)

quick_start = quick.index(
    "        Positioned.fill(\n          child: PointerInterceptor("
)
quick_end = quick.index("        if (sources.length > 1)", quick_start)
quick_block = quick[quick_start:quick_end]
quick_new_block = widen_three_tap_zones(quick_block, "quick-filter tap zones")
quick = quick[:quick_start] + quick_new_block + quick[quick_end:]

if "flex: 40" not in quick_new_block or "flex: 20" not in quick_new_block:
    raise SystemExit("quick-filter: widened tap zones were not installed")
quick_path.write_text(quick)


# ---------------------------------------------------------------------------
# Dedicated Properties teaser
# ---------------------------------------------------------------------------
property_path = ROOT / "lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart"
prop = property_path.read_text()

if "package:pointer_interceptor/pointer_interceptor.dart" not in prop:
    prop = replace_once(
        prop,
        "import 'package:video_player/video_player.dart';",
        "import 'package:video_player/video_player.dart';\nimport 'package:pointer_interceptor/pointer_interceptor.dart';",
        "property pointer-interceptor import",
    )

prop_start = prop.index("        Positioned.fill(\n          child: Row(")
prop_end = prop.index("        if (widget.media.length > 1)", prop_start)
prop_block = prop[prop_start:prop_end]
prop_block = widen_three_tap_zones(prop_block, "property tap zones")
prop_block = replace_once(
    prop_block,
    """        Positioned.fill(\n          child: Row(""",
    """        Positioned.fill(\n          child: PointerInterceptor(\n            // A playing web video must never steal the left/right navigation tap.\n            // Keep the shield active for photos too so behavior is identical.\n            intercepting: kIsWeb,\n            child: Row(""",
    "property pointer-interceptor wrapper open",
)
# The interaction block ends with Row -> Positioned. Add the PointerInterceptor close.
old_tail = """              ),\n            ],\n          ),\n        ),\n"""
new_tail = """              ),\n            ],\n            ),\n          ),\n        ),\n"""
prop_block = replace_once(
    prop_block,
    old_tail,
    new_tail,
    "property pointer-interceptor wrapper close",
)
prop = prop[:prop_start] + prop_block + prop[prop_end:]
property_path.write_text(prop)


# ---------------------------------------------------------------------------
# Events teaser: tap left/right instead of requiring a swipe.
# ---------------------------------------------------------------------------
events_path = ROOT / "lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart"
events = events_path.read_text()

if "package:pointer_interceptor/pointer_interceptor.dart" not in events:
    events = replace_once(
        events,
        "import 'package:video_player/video_player.dart';",
        "import 'package:video_player/video_player.dart';\nimport 'package:pointer_interceptor/pointer_interceptor.dart';",
        "events pointer-interceptor import",
    )

old_events_surface = """          // Tap + horizontal swipe live in a layer that excludes the media\n          // controls so sound/play stay instant and swiping still advances.\n          Positioned(\n            top: 0,\n            left: 0,\n            right: 48,\n            bottom: 72,\n            child: GestureDetector(\n              behavior: HitTestBehavior.opaque,\n              onTap: () => _openEvents(videos),\n              onHorizontalDragStart: (_) => _dragDx = 0,\n              onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,\n              onHorizontalDragEnd: (details) {\n                final velocity = details.primaryVelocity ?? 0;\n                final gesture = velocity.abs() >= 100 ? velocity : _dragDx;\n                if (videos.length > 1 &&\n                    (gesture.abs() >= 8 || _dragDx.abs() >= 8)) {\n                  AppHaptics.selection();\n                  unawaited(_advance(gesture < 0 ? 1 : -1));\n                }\n                _dragDx = 0;\n              },\n              child: const SizedBox.expand(),\n            ),\n          ),\n"""

new_events_surface = """          // The dashboard contract is the same for every quick filter:\n          // tap LEFT = previous, tap CENTER = open, tap RIGHT = next. Swiping\n          // remains optional, but is never required. Keep controls excluded.\n          Positioned(\n            top: 0,\n            left: 0,\n            right: 48,\n            bottom: 72,\n            child: PointerInterceptor(\n              intercepting: kIsWeb,\n              child: LayoutBuilder(\n                builder: (context, constraints) => GestureDetector(\n                  behavior: HitTestBehavior.opaque,\n                  onTapUp: (details) {\n                    final width = constraints.maxWidth;\n                    final x = details.localPosition.dx;\n                    if (videos.length > 1 && x < width * .40) {\n                      AppHaptics.selection();\n                      unawaited(_advance(-1));\n                      return;\n                    }\n                    if (videos.length > 1 && x > width * .60) {\n                      AppHaptics.selection();\n                      unawaited(_advance(1));\n                      return;\n                    }\n                    _openEvents(videos);\n                  },\n                  onHorizontalDragStart: (_) => _dragDx = 0,\n                  onHorizontalDragUpdate: (details) =>\n                      _dragDx += details.delta.dx,\n                  onHorizontalDragEnd: (details) {\n                    final velocity = details.primaryVelocity ?? 0;\n                    final gesture = velocity.abs() >= 100 ? velocity : _dragDx;\n                    if (videos.length > 1 &&\n                        (gesture.abs() >= 8 || _dragDx.abs() >= 8)) {\n                      AppHaptics.selection();\n                      unawaited(_advance(gesture < 0 ? 1 : -1));\n                    }\n                    _dragDx = 0;\n                  },\n                  child: const SizedBox.expand(),\n                ),\n              ),\n            ),\n          ),\n"""

events = replace_once(
    events,
    old_events_surface,
    new_events_surface,
    "events left/center/right tap surface",
)
events = events.replace(
    "Live event stream · swipe left or right",
    "Tap left/right · center opens",
)
events_path.write_text(events)

print("Installed reliable 40/20/40 quick-filter edge taps for photos and videos.")
