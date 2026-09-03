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

  // Never pass an already-exported WebM straight through as a public listing
  // video. Chromium can play it, but native iOS AVPlayer cannot. Only skip the
  // optimizer when the existing clip is already in an Apple-safe MP4/MOV/M4V
  // container.
  if (alreadyOptimized && _isApplePlayableVideo(source)) return source;

  try {
    // The browser exporter reads metadata and clamps 60s to the real duration.
    final optimized = await recutVideoWindowV2(
      source: source,
      start: 0,
      end: 60,
      portraitCrop: true,
      includeOriginalAudio: true,
    );

    // Safari can export MP4 directly. Chrome/Firefox commonly fall back to
    // WebM; in that case keep the original phone MP4/MOV instead of publishing
    // a dashboard video that would disappear on the native iOS app.
    if (_isApplePlayableVideo(optimized)) return optimized;
    if (_isApplePlayableVideo(source)) return source;

    // A genuinely WebM-only source has no client-side path to H.264 in browsers
    // that lack MP4 MediaRecorder support. Keep it rather than corrupting the
    // upload; native/iOS compatibility for such legacy files requires server
    // transcoding.
    return optimized;
  } catch (_) {
    return source;
  }
}
