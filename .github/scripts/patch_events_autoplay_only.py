from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected one match for {label}, found {count}")
    return text.replace(old, new, 1)


path = Path("lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart")
text = path.read_text()

pause_control = """                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _toggleVideoPreview,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(132),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(48)),
                      ),
                      child: Icon(
                        _videoPreviewEnabled
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
"""
text = replace_once(text, pause_control, "", "Events play/pause control")

text = replace_once(
    text,
    "                    _videoPreviewEnabled ? 'EVENTS  •  LIVE' : 'EVENTS  •  PAUSED',\n",
    "                    'EVENTS  •  LIVE',\n",
    "Events LIVE label",
)

old_subtitle = """                            _videoPreviewEnabled
                                ? (videos.length > 1
                                    ? 'Live event stream · swipe left or right'
                                    : 'Tap to explore events')
                                : 'Video preview off · tap play to resume',
"""
new_subtitle = """                            videos.length > 1
                                ? 'Live event stream · swipe left or right'
                                : 'Tap to explore events',
"""
text = replace_once(text, old_subtitle, new_subtitle, "Events live subtitle")

path.write_text(text)
print("Patched Events dashboard teaser: autoplay stays on; only the sound control remains; video stays portrait-cropped with BoxFit.cover.")
