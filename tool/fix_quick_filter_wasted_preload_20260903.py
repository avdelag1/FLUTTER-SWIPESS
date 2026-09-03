from pathlib import Path
import re

path = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = path.read_text()
original = text

# Gemini's dashboard preloader creates a second VideoPlayerController, but
# _advance() immediately calls _disposeVideo(), which disposes that preload
# before _syncVideo() can ever adopt it. That wastes network + decoder/GPU
# resources on mobile PWA and can make the active video stutter.
text = text.replace('  VideoPlayerController? _preloaded;\n', '')
text = text.replace('  String? _preloadedUrl;\n', '')

text = text.replace(
    '    _preloaded?.dispose();\n'
    '    _preloaded = null;\n'
    '    _preloadedUrl = null;\n',
    '',
)

# Remove the unused dashboard preload call. Keep CapSwipeCard's separate
# preload path untouched because that implementation actually adopts its
# prepared controller when the next media item is selected.
text = text.replace('      unawaited(_preloadNext());\n', '')

pattern = re.compile(
    r'\n  Future<void> _preloadNext\(\) async \{.*?\n  \}\n\n  void _onSoundChanged',
    re.DOTALL,
)
text, count = pattern.subn('\n  void _onSoundChanged', text, count=1)
if count != 1:
    raise SystemExit('Expected to remove exactly one _preloadNext method')

# Non-Event listing videos are manual playback. Starting ownership at only 20%
# visibility pauses Events / spends playback resources while the listing is
# mostly off-screen, yet _playIfReady still requires 50%. Keep those gates
# consistent and avoid premature work.
text = text.replace('_visibleFraction >= 0.20', '_visibleFraction >= 0.50')

if text == original:
    raise SystemExit('No changes applied')

if '_preloaded' in text or '_preloadNext()' in text:
    raise SystemExit('Broken quick-filter preload symbols still present')

path.write_text(text)
print('Removed wasted quick-filter preload and restored 50% playback gate')
