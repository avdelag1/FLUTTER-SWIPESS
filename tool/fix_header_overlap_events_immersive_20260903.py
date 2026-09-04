from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Dashboard shell: Events is ALWAYS immersive. The shared header/dock must not
# race EventsScreen and reappear on the first frame or on vertical scroll.
# ---------------------------------------------------------------------------
shell_path = ROOT / "lib/src/features/dashboard/presentation/screens/dashboard_shell.dart"
shell = shell_path.read_text()

shell = replace_once(
    shell,
    """        // Events can collapse their own likes/category controls to let the\n        // video grow vertically, but that local immersion must not also hide\n        // the app's primary header/dock. User-driven scroll can still fade it.\n        chrome.suppressExplicitHide(location == AppPaths.exploreEvents);\n        chrome.show();""",
    """        // Events owns the entire viewport. Never let the shared dashboard\n        // header/dock race the EventsScreen immersive state on route entry.\n        chrome.suppressExplicitHide(false);\n        if (location == AppPaths.exploreEvents) {\n          chrome.hide();\n        } else {\n          chrome.show();\n        }""",
    "shell events route-entry chrome",
)

shell = replace_once(
    shell,
    """    final persistentChromeVisible = chromeOpacity > 0.01 && shellRouteIsCurrent;\n    final showHeader = persistentChromeVisible;""",
    """    // Main Events is permanently immersive at the shell level. Its own eye\n    // control may reveal event actions, but never the global header/dock.\n    final persistentChromeVisible =\n        !isEvents && chromeOpacity > 0.01 && shellRouteIsCurrent;\n    final showHeader = persistentChromeVisible;""",
    "shell persistent chrome events guard",
)

shell = replace_once(
    shell,
    """              if (notification.depth == 0 &&\n                  notification.metrics.axis == Axis.vertical &&\n                  notification is ScrollUpdateNotification) {""",
    """              if (!isEvents &&\n                  notification.depth == 0 &&\n                  notification.metrics.axis == Axis.vertical &&\n                  notification is ScrollUpdateNotification) {""",
    "shell ignore events scroll chrome",
)

shell = shell.replace(
    "// viewport and the shared header/dock float above it.",
    "// viewport; the shared header/dock are intentionally suppressed.",
)
shell_path.write_text(shell)


# ---------------------------------------------------------------------------
# Events opener: arrive hidden on frame zero instead of showing shared chrome
# and relying on EventsScreen to hide it a frame later.
# ---------------------------------------------------------------------------
open_events_path = ROOT / "lib/src/features/events/presentation/utils/open_events_feed.dart"
open_events = open_events_path.read_text()
open_events = replace_once(
    open_events,
    """    // Events must paint with the real app header + dock visible on its very\n    // first frame. Previously a hidden dashboard/listing state could survive\n    // the route change, so the video appeared first and navigation popped in\n    // one frame later. Events owns the later immersive auto-hide itself.\n    resolved.read(chromeVisibilityProvider.notifier).show();""",
    """    // Events is immersive from frame zero: hide the shared dashboard\n    // header + dock before navigation so they never flash over the video.\n    resolved.read(chromeVisibilityProvider.notifier).hide();""",
    "events opener immersive chrome",
)
open_events_path.write_text(open_events)


# ---------------------------------------------------------------------------
# Dashboard: quick-filter cards must begin below the floating header/search bar.
# The clearance scrolls away naturally when the user moves down the dashboard.
# ---------------------------------------------------------------------------
bento_path = ROOT / "lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart"
bento = bento_path.read_text()
bento = replace_once(
    bento,
    "padding: EdgeInsets.fromLTRB(16, 4, 16, bottomScrollPad),",
    "padding: EdgeInsets.fromLTRB(16, 64, 16, bottomScrollPad),",
    "dashboard header clearance",
)
bento_path.write_text(bento)


# ---------------------------------------------------------------------------
# Listing detail: keep the hero media below the global header while at the top.
# The spacer belongs to the scroll content, so it disappears naturally as the
# shared chrome fades and the user scrolls into the detail page.
# ---------------------------------------------------------------------------
listing_path = ROOT / "lib/src/features/swipes/presentation/screens/listing_detail_screen.dart"
listing = listing_path.read_text()
listing = replace_once(
    listing,
    """              slivers: [\n                SliverToBoxAdapter(\n                  child: SizedBox(\n                    height: heroH,""",
    """              slivers: [\n                // Clear the persistent app header on first paint. Because this\n                // is a sliver, the clearance scrolls away with the hero instead\n                // of leaving a permanent empty band after chrome auto-hides.\n                SliverToBoxAdapter(child: SizedBox(height: top + 58)),\n                SliverToBoxAdapter(\n                  child: SizedBox(\n                    height: heroH,""",
    "listing hero header clearance",
)
listing_path.write_text(listing)


# ---------------------------------------------------------------------------
# Profile: give its own title/action row a little more breathing room below the
# global search/header instead of sitting visually underneath the HUD buttons.
# ---------------------------------------------------------------------------
profile_path = ROOT / "lib/src/features/profile/presentation/screens/profile_screen.dart"
profile = profile_path.read_text()
profile = replace_once(
    profile,
    "edgeOffset: safe.top + 50,\n            displacement: safe.top + 68,",
    "edgeOffset: safe.top + 66,\n            displacement: safe.top + 84,",
    "profile refresh header clearance",
)
profile = replace_once(
    profile,
    """                16,\n                safe.top + 68,\n                16,""",
    """                16,\n                safe.top + 84,\n                16,""",
    "profile content header clearance",
)
profile_path.write_text(profile)

print("Fixed header overlap and made Events shell chrome permanently immersive.")
