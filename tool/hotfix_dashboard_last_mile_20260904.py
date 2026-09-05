from pathlib import Path


def replace_required(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Missing target for {label}: {path}")
    p.write_text(text.replace(old, new, 1))


# Keep the AI prompt readable like a real marquee: continuous linear motion,
# enough time for a human to read the whole phrase, and the next phrase already
# following behind the current one with no blink/swap effect.
replace_required(
    "lib/src/core/widgets/glow_search_bar.dart",
    "const Duration(milliseconds: 8300)",
    "const Duration(milliseconds: 12000)",
    "prompt cadence",
)
replace_required(
    "lib/src/core/widgets/glow_search_bar.dart",
    "duration: const Duration(milliseconds: 8200)",
    "duration: const Duration(milliseconds: 12000)",
    "marquee travel duration",
)

print("Dashboard AI marquee slowed to a smooth 12-second continuous handoff.")
