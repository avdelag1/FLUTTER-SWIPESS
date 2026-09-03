import 'package:image_picker/image_picker.dart';
import 'package:flutter_swipes/src/features/camera/data/video_recut_v3_html.dart';

bool _isApplePlayableVideo(XFile file) {
  final mime = file.mimeType?.trim().toLowerCase() ?? '';
  if (mime == 'video/mp4' ||
      mime == 'video/quicktime' ||
      mime == 'video/x-m4v') {
    return true;
  }
  final lower = file.name.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v');
}

Future<XFile> optimizeVideoForUpload(XFile source) async {
  final lowerName = source.name.toLowerCase();
  final alreadyOptimized =
      lowerName.startsWith('swipess-optimized') ||
      lowerName.startsWith('swipess-portrait-');

  // A .mp4 extension only describes the container. Phone uploads can still be
  // 4K/HEVC/high-bitrate files, which was the exact path that made listing
  // videos choke while the already-normalized Events clips stayed smooth. Try
  // the delivery export for every new browser upload; only keep the source if
  // this browser cannot make an Apple-playable replacement.
  if (alreadyOptimized && _isApplePlayableVideo(source)) return source;

  try {
    final optimized = await recutVideoWindowV2(
      source: source,
      start: 0,
      end: 60,
      portraitCrop: true,
      includeOriginalAudio: true,
    );

    // Prefer the compact 9:16 export whenever the browser produced a container
    // that native iOS can consume directly.
    if (_isApplePlayableVideo(optimized)) return optimized;

    // Some Chrome/Android/desktop browsers only let MediaRecorder export WebM.
    // Never publish that WebM when the user's original is already MP4/MOV/M4V:
    // the same listing must remain playable later from the native iOS app.
    // Quick-filter/deck rendering still uses BoxFit.cover for portrait display.
    if (_isApplePlayableVideo(source)) return source;

    // A genuinely WebM-only source has no Apple-compatible representation in
    // the browser without a server-side transcoder. Keep it rather than losing
    // the upload; native iOS surfaces provide a poster fallback for such legacy
    // media until it is replaced by an MP4/MOV upload.
    return optimized;
  } catch (_) {
    return source;
  }
}
