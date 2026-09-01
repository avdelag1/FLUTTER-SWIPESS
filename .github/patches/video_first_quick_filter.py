from pathlib import Path

p = Path('lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart')
s = p.read_text()
old = """    final out = <String>[...widget.listing.images];
    final video = widget.listing.videoUrl;
    if (video != null && video.isNotEmpty && !out.contains(video))
      out.add(video);
    return out;
"""
new = """    final out = <String>[...widget.listing.images];
    final video = widget.listing.videoUrl;
    if (video != null && video.isNotEmpty && !out.contains(video)) {
      out.insert(0, video);
    }
    return out;
"""
if s.count(old) != 1:
    raise SystemExit(f'expected one card media block, found {s.count(old)}')
p.write_text(s.replace(old, new, 1))
print('quick-filter swipe cards now render listing video first')
