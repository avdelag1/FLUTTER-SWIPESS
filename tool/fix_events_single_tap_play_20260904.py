from pathlib import Path

path = Path('lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart')
text = path.read_text()
old = '''  void _toggleVideoPreview() {
    AppHaptics.selection();
    final next = !_videoPreviewEnabled;
    setState(() => _videoPreviewEnabled = next);

    if (!next) {
'''
new = '''  void _toggleVideoPreview() {
    AppHaptics.selection();
    final next = !_videoPreviewEnabled;

    // An explicit Play tap must reclaim Events playback immediately. A listing
    // preview can leave this card externally paused; if that flag survives the
    // user's tap, _canPlay stays false and the first tap only changes the icon.
    if (next) _externallyPaused = false;
    setState(() => _videoPreviewEnabled = next);

    if (!next) {
'''
if new in text:
    print('Events single-tap fix already applied')
elif old in text:
    path.write_text(text.replace(old, new, 1))
    print('Patched Events single-tap playback')
else:
    raise SystemExit('Expected Events toggle block not found')
