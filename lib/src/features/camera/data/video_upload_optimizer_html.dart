import 'package:flutter/foundation.dart';
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
  // encoder again so iOS has a chance to produce MP4.
  if (alreadyOptimized && _isApplePlayableVideo(source)) return source;

  try {
    // Always use the 9:16 540x960 browser export for Android/desktop web. The
    // previous fallback returned the original phone MP4 whenever Chrome emitted
    // WebM, which threw away the portrait crop and sent a much larger raw file
    // to Storage. That is exactly the path that made PWA media uploads fail.
    final optimized = await recutVideoWindowV2(
      source: source,
      start: 0,
      end: 60,
      portraitCrop: true,
      includeOriginalAudio: true,
    );

    if (_isApplePlayableVideo(optimized)) return optimized;

    // iOS native playback cannot rely on WebM. Safari normally exports MP4;
    // only on iOS, if it does not, keep the original Apple-playable clip rather
    // than publishing an incompatible video. Android/desktop keep the smaller
    // portrait WebM export because it is natively supported there.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        _isApplePlayableVideo(source)) {
      return source;
    }

    return optimized;
  } catch (_) {
    return source;
  }
}
