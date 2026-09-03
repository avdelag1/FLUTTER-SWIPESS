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
  final alreadyOptimized = lowerName.startsWith('swipess-optimized') ||
      lowerName.startsWith('swipess-portrait-');

  // Do not re-encode a finished Swipess export when the container is already
  // safe for Apple playback. WebM exports are allowed to run through the
  // encoder again so the browser has a chance to produce MP4.
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
