from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


repo = Path('lib/src/features/swipes/data/repositories/listing_repository.dart')
s = repo.read_text()
if "video_upload_optimizer.dart" not in s:
    s = replace_once(
        s,
        "import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';\n",
        "import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';\n"
        "import 'package:flutter_swipes/src/features/camera/data/video_upload_optimizer.dart';\n",
        'listing repository optimizer import',
    )

old = """  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected video is empty. Please choose the clip again.');
    }
    if (bytes.lengthInBytes > 50 * 1024 * 1024) {
      throw Exception('Video must be under 50MB.');
    }
    final lower = file.name.toLowerCase();
"""
new = """  }) async {
    // One delivery path for iOS, Android, PWA and web. Even if a caller skips
    // the editor, raw phone HEVC/MOV/4K media is normalized before it becomes a
    // public dashboard URL. Already-exported Swipess clips are passed through.
    final optimized = await optimizeVideoForUpload(file);
    final bytes = await optimized.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected video is empty. Please choose the clip again.');
    }
    if (bytes.lengthInBytes > 50 * 1024 * 1024) {
      throw Exception('Optimized video must be under 50MB.');
    }
    final lower = optimized.name.toLowerCase();
"""
if old in s:
    s = replace_once(s, old, new, 'universal upload optimizer')
elif 'final optimized = await optimizeVideoForUpload(file);' not in s:
    raise SystemExit('universal upload optimizer: source pattern not found')
repo.write_text(s)


quick = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
q = quick.read_text()
q = q.replace(
    'static int get maxActive => kIsWeb ? 2 : 3;',
    'static int get maxActive => 4;',
    1,
)
q = q.replace(
    'double get _previewWarmupThreshold => kIsWeb ? 0.22 : 0.16;',
    'double get _previewWarmupThreshold => kIsWeb ? 0.12 : 0.10;',
    1,
)

old = """      await next.setLooping(false);
      await next.setVolume(0);
      _attachPlayerListener(next);
"""
new = """      await next.setLooping(false);
      await next.setVolume(0);
      // Decode a real movie frame while the card is still paused. The user sees
      // the actual video preview (not a listing photo) and Play has no cold-start
      // seek/decode penalty. Keep the warm frame silent and stationary.
      if (!autoPlay && next.value.duration.inMilliseconds > 120) {
        await next.seekTo(const Duration(milliseconds: 90));
        await next.pause();
      }
      _attachPlayerListener(next);
"""
if old in q:
    q = replace_once(q, old, new, 'decoded preview frame')
elif 'Decode a real movie frame while the card is still paused' not in q:
    raise SystemExit('decoded preview frame: source pattern not found')

old = """      if (duration.inMilliseconds > 0 &&
          position.inMilliseconds >= duration.inMilliseconds - 180) {
        await player.seekTo(Duration.zero);
      }
      await player.setVolume(wantSound ? 1 : 0);
"""
new = """      if (duration.inMilliseconds > 0 &&
          position.inMilliseconds >= duration.inMilliseconds - 180) {
        await player.seekTo(Duration.zero);
      } else if (position.inMilliseconds > 0 && position.inMilliseconds <= 140) {
        // Warm previews sit on frame ~90ms. A deliberate Play starts the clip
        // from frame zero so the user never loses the opening moment.
        await player.seekTo(Duration.zero);
      }
      await player.setVolume(wantSound ? 1 : 0);
"""
if old in q:
    q = replace_once(q, old, new, 'play from zero after preview warmup')
elif 'Warm previews sit on frame ~90ms' not in q:
    raise SystemExit('play from zero after preview warmup: source pattern not found')

quick.write_text(q)
