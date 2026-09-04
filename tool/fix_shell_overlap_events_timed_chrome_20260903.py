from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Dashboard shell
# - Requests + Messages must live BELOW the real shared header and ABOVE dock.
# - Events must be allowed to show that same shared chrome on entry, then the
#   EventsScreen timer owns the later immersive hide.
# ---------------------------------------------------------------------------
shell_path = ROOT / "lib/src/features/dashboard/presentation/screens/dashboard_shell.dart"
shell = shell_path.read_text()

shell = replace_once(
    shell,
    """        // Events owns the entire viewport. Never let the shared dashboard
        // header/dock race the EventsScreen immersive state on route entry.
        chrome.suppressExplicitHide(false);
        if (location == AppPaths.exploreEvents) {
          chrome.hide();
        } else {
          chrome.show();
        }""",
    """        // Paint the real app navigation first on every shell destination.
        // EventsScreen owns the later timed immersive hide, so route entry must
        // never force Events hidden before the user has seen the header + dock.
        chrome.suppressExplicitHide(false);
        chrome.show();""",
    "shell events route-entry chrome",
)

shell = replace_once(
    shell,
    """    // Virtual ID uses the same immersive contract as listings/events: chrome
    // may fade away, but the shared controls are still allowed to render while
    // visible so the user sees them first and can maneuver immediately.
    // Main Events is permanently immersive at the shell level. Its own eye
    // control may reveal event actions, but never the global header/dock.
    final persistentChromeVisible =
        !isEvents && chromeOpacity > 0.01 && shellRouteIsCurrent;""",
    """    // The provider is the single source of truth for the real app header/dock.
    // EventsScreen toggles this provider together with its local event controls,
    // which keeps the card resize and the global chrome perfectly synchronized.
    final persistentChromeVisible =
        chromeOpacity > 0.01 && shellRouteIsCurrent;""",
    "shell allow Events shared chrome",
)

shell = replace_once(
    shell,
    """    final isLikes =
        location == AppPaths.clientLikedProperties ||
        location == AppPaths.ownerLikedClients;

    final routeTab = AppPaths.tabForLocation(location);""",
    """    final isLikes =
        location == AppPaths.clientLikedProperties ||
        location == AppPaths.ownerLikedClients;
    // These shell-owned root pages deliberately rely on the shared header/dock.
    // Reserve that space centrally so their own title/search rows never render
    // underneath the floating app chrome on Android, iOS, or PWA.
    final needsPersistentChromeInsets =
        isLikes ||
        location == AppPaths.messages ||
        location == AppPaths.exploreSeekers;

    final routeTab = AppPaths.tabForLocation(location);""",
    "shell persistent page inset set",
)

shell = replace_once(
    shell,
    """                if (!isDashboard && !isEvents)
                  isLikes
                      ? _withPersistentChromeInsets(
                          context,
                          IosMotion.crossFade(
                            key: location,
                            child: widget.child,
                          ),
                        )
                      : IosMotion.crossFade(key: location, child: widget.child),""",
    """                if (!isDashboard && !isEvents)
                  needsPersistentChromeInsets
                      ? _withPersistentChromeInsets(
                          context,
                          IosMotion.crossFade(
                            key: location,
                            child: widget.child,
                          ),
                        )
                      : IosMotion.crossFade(key: location, child: widget.child),""",
    "shell apply insets to Requests and Messages",
)

shell = shell.replace(
    "// viewport; the shared header/dock are intentionally suppressed.",
    "// viewport; shared chrome floats above it until EventsScreen hides it.",
)

shell = replace_once(
    shell,
    """            visible:
                persistentChromeVisible ||
                isProfile ||
                !_chromeMayAutoHide(location),""",
    """            visible:
                isEvents ||
                persistentChromeVisible ||
                isProfile ||
                !_chromeMayAutoHide(location),""",
    "disable shell summon zones on Events",
)

shell_path.write_text(shell)


# ---------------------------------------------------------------------------
# Events opener: reveal shared app chrome BEFORE navigation. This prevents a
# hidden state inherited from a dashboard/listing from making Events start in
# the wrong visual state.
# ---------------------------------------------------------------------------
open_events_path = ROOT / "lib/src/features/events/presentation/utils/open_events_feed.dart"
open_events = open_events_path.read_text()
open_events = replace_once(
    open_events,
    """    // Events is immersive from frame zero: hide the shared dashboard
    // header + dock before navigation so they never flash over the video.
    resolved.read(chromeVisibilityProvider.notifier).hide();""",
    """    // Events follows the swipe-deck reveal contract: show the real app
    // header + dock immediately, then EventsScreen auto-hides them with its card.
    resolved.read(chromeVisibilityProvider.notifier).show();""",
    "events opener reveals shared chrome",
)
open_events_path.write_text(open_events)


# ---------------------------------------------------------------------------
# Events screen: start compact with navigation visible, then after six seconds
# hide BOTH local controls and shared app chrome. The existing AnimatedPadding
# expands the card while keeping the same video controller alive, so playback
# and audio are not restarted during the transition.
# ---------------------------------------------------------------------------
events_path = ROOT / "lib/src/features/events/presentation/screens/events_screen.dart"
events = events_path.read_text()
events = replace_once(
    events,
    """    // Events open directly in immersive mode. Hide the shared header/bottom
    // chrome in the same state change that lets the event card fill the screen.
    _chromeVisible = false;
    ref.read(chromeVisibilityProvider.notifier).hide();""",
    """    // Match the swipe-card contract: first paint is compact with the real
    // app header/dock and event actions visible. After six seconds _showChrome
    // drives the existing timer, which hides both layers and expands the card.
    _chromeVisible = true;
    ref.read(chromeVisibilityProvider.notifier).show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showChrome();
    });""",
    "events initial timed chrome",
)
events_path.write_text(events)


# ---------------------------------------------------------------------------
# Regression guards. These are source-contract tests on purpose: they protect
# the exact shell/event handshake that was accidentally inverted by the prior
# hotfix without requiring network/video fixtures.
# ---------------------------------------------------------------------------
test_path = ROOT / "test/persistent_chrome_overlap_guard_test.dart"
test = test_path.read_text()
anchor = """  test('Settings hierarchy keeps its own safe, scrollable top controls', () {"""
insert = """  test('Requests and Messages reserve shared chrome while Events uses timed reveal', () {
    final shell = File(
      'lib/src/features/dashboard/presentation/screens/dashboard_shell.dart',
    ).readAsStringSync();
    final events = File(
      'lib/src/features/events/presentation/screens/events_screen.dart',
    ).readAsStringSync();
    final opener = File(
      'lib/src/features/events/presentation/utils/open_events_feed.dart',
    ).readAsStringSync();

    expect(shell, contains('final needsPersistentChromeInsets ='));
    expect(shell, contains('location == AppPaths.messages'));
    expect(shell, contains('location == AppPaths.exploreSeekers'));
    expect(shell, contains('needsPersistentChromeInsets'));
    expect(shell, isNot(contains('!isEvents && chromeOpacity')));
    expect(
      shell,
      contains('isEvents ||'),
      reason: 'Events must disable shell summon zones so only its eye control changes both chrome layers',
    );

    expect(events, contains('static const _chromeTimeout = Duration(seconds: 6);'));
    expect(events, contains('_chromeVisible = true;'));
    expect(events, contains('_showChrome();'));
    expect(opener, contains('chromeVisibilityProvider.notifier).show()'));
  });

"""
test = replace_once(test, anchor, insert + anchor, "chrome regression test insertion")
test_path.write_text(test)

print("Fixed Requests/Messages header overlap and restored timed Events chrome reveal.")
