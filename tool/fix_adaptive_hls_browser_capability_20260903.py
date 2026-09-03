from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)

stub = Path('lib/src/core/performance/video_platform_context_stub.dart')
text = stub.read_text()
if 'supportsNativeWebHls' not in text:
    text = text.rstrip() + "\n\nbool get supportsNativeWebHls => false;\n"
stub.write_text(text)

web = Path('lib/src/core/performance/video_platform_context_web.dart')
text = web.read_text()
if 'supportsNativeWebHls' not in text:
    text = text.rstrip() + r'''

bool get supportsNativeWebHls {
  try {
    final element = web.document.createElement('video');
    if (element is! web.HTMLVideoElement) return false;
    final apple = element.canPlayType('application/vnd.apple.mpegurl');
    final legacy = element.canPlayType('application/x-mpegURL');
    return apple.isNotEmpty || legacy.isNotEmpty;
  } catch (_) {
    return false;
  }
}
'''
web.write_text(text)

model = Path('lib/src/features/swipes/domain/models/listing.dart')
text = model.read_text()
text = replace_once(
    text,
    "import 'package:flutter/foundation.dart';\n",
    "import 'package:flutter/foundation.dart';\n"
    "import 'package:flutter_swipes/src/core/performance/video_platform_context.dart';\n",
    'listing native HLS capability import',
)
old = r'''  String? get preferredVideoUrl {
    final mp4 = videoUrl?.trim();
    final hls = videoHlsUrl?.trim();
    final nativeHls = !kIsWeb;
    final webkitHls =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if ((nativeHls || webkitHls) && hls != null && hls.isNotEmpty) {
      return hls;
    }
    return mp4 == null || mp4.isEmpty ? null : mp4;
  }
'''
new = r'''  String? get preferredVideoUrl {
    final mp4 = videoUrl?.trim();
    final hls = videoHlsUrl?.trim();
    // Native AVPlayer/ExoPlayer can consume HLS. On web, ask the browser's
    // video element directly rather than guessing from OS: Chrome on macOS is
    // still Chrome and must retain the fast-start MP4 fallback.
    final canUseAdaptiveHls = !kIsWeb || supportsNativeWebHls;
    if (canUseAdaptiveHls && hls != null && hls.isNotEmpty) return hls;
    return mp4 == null || mp4.isEmpty ? null : mp4;
  }
'''
text = replace_once(text, old, new, 'listing browser-native HLS getter')
model.write_text(text)

print('adaptive HLS browser capability guard applied')
