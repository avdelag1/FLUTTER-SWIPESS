from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)

listing = Path('lib/src/features/swipes/domain/models/listing.dart')
text = listing.read_text()
text = replace_once(
    text,
    "  final String? videoUrl;\n  final String? videoHlsUrl;",
    "  final String? videoUrl;\n  final String? videoOriginalUrl;\n  final String? videoHlsUrl;",
    'listing fields',
)
text = replace_once(
    text,
    "    this.videoUrl,\n    this.videoHlsUrl,",
    "    this.videoUrl,\n    this.videoOriginalUrl,\n    this.videoHlsUrl,",
    'listing constructor',
)
text = replace_once(
    text,
    "      videoUrl: json['video_url'] as String?,\n      videoHlsUrl: json['video_hls_url'] as String?,",
    "      videoUrl: json['video_url'] as String?,\n      videoOriginalUrl: json['video_original_url'] as String?,\n      videoHlsUrl: json['video_hls_url'] as String?,",
    'listing json',
)
old_getter = '''  String? get preferredVideoUrl {\n    final mp4 = videoUrl?.trim();\n    final hls = videoHlsUrl?.trim();\n\n    // Short listing previews on Flutter Web/PWA are measurably smoother with\n    // the fast-start progressive MP4. Native HLS support can report available\n    // on some browsers/devices yet still incur manifest/segment startup and\n    // early rebuffering. Keep adaptive HLS for native AVPlayer/ExoPlayer, while\n    // web/PWA uses the already-optimized MP4 with byte-range delivery.\n    if (kIsWeb) {\n      if (mp4 != null && mp4.isNotEmpty) return mp4;\n      return hls == null || hls.isEmpty ? null : hls;\n    }\n\n    if (hls != null && hls.isNotEmpty) return hls;\n    return mp4 == null || mp4.isEmpty ? null : mp4;\n  }\n'''
new_getter = '''  String? get preferredVideoUrl {\n    final original = videoOriginalUrl?.trim();\n    final mp4 = videoUrl?.trim();\n    final hls = videoHlsUrl?.trim();\n\n    // Web/PWA intentionally mirrors Admin Events: play the exact raw file that\n    // was uploaded to Supabase. This removes both browser-side re-recording and\n    // processed-rendition cadence as variables from the Properties canary.\n    if (kIsWeb) {\n      if (original != null && original.isNotEmpty) return original;\n      if (mp4 != null && mp4.isNotEmpty) return mp4;\n      return hls == null || hls.isEmpty ? null : hls;\n    }\n\n    // Native apps keep adaptive delivery first, then the processed MP4, with\n    // the original source as a final compatibility fallback.\n    if (hls != null && hls.isNotEmpty) return hls;\n    if (mp4 != null && mp4.isNotEmpty) return mp4;\n    return original == null || original.isEmpty ? null : original;\n  }\n'''
text = replace_once(text, old_getter, new_getter, 'preferredVideoUrl')
listing.write_text(text)

repo = Path('lib/src/features/swipes/data/repositories/listing_repository.dart')
text = repo.read_text()
text = replace_once(
    text,
    "    id, title, description, price, images, video_url, video_hls_url,",
    "    id, title, description, price, images, video_url, video_original_url, video_hls_url,",
    'repository swipe fields',
)
repo.write_text(text)

print('Admin-style listing video route model patch applied.')
