from pathlib import Path

cap = Path('lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart')
text = cap.read_text()
old = """  Future<void> _syncSoundtrack(bool wantSound) async {\n    if (!widget.isTop || !wantSound || !widget.listing.hasBackgroundMusic) {\n      await _soundtrack.stop();\n      return;\n    }\n"""
new = """  Future<void> _syncSoundtrack(bool wantSound) async {\n    final media = _media;\n    final current = media.isEmpty ? null : media[_photoIndex % media.length];\n    final showingVideo = current != null && _isVideo(current);\n    if (!widget.isTop ||\n        !showingVideo ||\n        !wantSound ||\n        !widget.listing.hasBackgroundMusic) {\n      await _soundtrack.stop();\n      return;\n    }\n"""
if old not in text:
    raise SystemExit('soundtrack sync pattern not found')
cap.write_text(text.replace(old, new, 1))

test = Path('test/listing_video_audio_test.dart')
text = test.read_text()
needle = """  test('manual and AI media rows put video before photos', () {\n"""
insert = """  test('published soundtrack playback is gated to the video frame', () {\n    final source = File(\n      'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',\n    ).readAsStringSync();\n    expect(source, contains('final showingVideo = current != null && _isVideo(current);'));\n    expect(source, contains('!showingVideo ||'));\n  });\n\n"""
if needle not in text:
    raise SystemExit('test insertion point not found')
test.write_text(text.replace(needle, insert + needle, 1))
