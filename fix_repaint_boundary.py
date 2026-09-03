from pathlib import Path
import re

files = [
    "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart",
    "lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart",
    "lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart",
]

for p in files:
    path = Path(p)
    text = path.read_text()
    
    # 1. Quick Filter Media
    if "quick_filter_media" in p:
        text = text.replace(
            "child: RepaintBoundary(\n                    child: VideoPlayer(player),\n                  )",
            "child: VideoPlayer(player)"
        )
        text = text.replace(
            "child: RepaintBoundary(child: VideoPlayer(player))",
            "child: VideoPlayer(player)"
        )
        
    # 2. Events Teaser Card V2
    elif "events_teaser_card_v2" in p:
        text = text.replace(
            "child: RepaintBoundary(\n          child: VideoPlayer(controller),\n        )",
            "child: VideoPlayer(controller)"
        )
        text = text.replace(
            "child: RepaintBoundary(child: VideoPlayer(controller))",
            "child: VideoPlayer(controller)"
        )
        text = text.replace(
            "child: RepaintBoundary(\n          child: VideoPlayer(player),\n        )",
            "child: VideoPlayer(player)"
        )

    # 3. Cap Swipe Card
    elif "cap_swipe_card" in p:
        text = text.replace(
            "child: RepaintBoundary(child: _coverVideo(player)),",
            "child: _coverVideo(player),"
        )
        text = text.replace(
            "child: RepaintBoundary(\n                child: _coverVideo(player),\n              )",
            "child: _coverVideo(player)"
        )

    path.write_text(text)
print("RepaintBoundaries removed!")
