from pathlib import Path

p = Path("lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart")
s = p.read_text()
old = """    _cursor = target;
    _preloadedVideos[listingId] = controller;
  }
"""
new = """    _cursor = target;
    _preloadedVideos[listingId] = controller;
    // Keep the metadata beside the same controller until the top card consumes
    // it. This preserves the dashboard timestamp AND the local sound intent;
    // the prepared-controller map only solves instant first paint.
    SwipeDeckMediaHandoff.set(handoff);
  }
"""
if new not in s:
    if old not in s:
        raise SystemExit("missing patch anchor: preserve dashboard handoff metadata")
    s = s.replace(old, new, 1)
p.write_text(s)
