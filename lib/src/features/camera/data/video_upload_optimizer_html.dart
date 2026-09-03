import 'package:image_picker/image_picker.dart';
import 'package:flutter_swipes/src/features/camera/data/video_recut_v3_html.dart';

Future<XFile> optimizeVideoForUpload(XFile source) async {
  final lowerName = source.name.toLowerCase();
  final alreadyOptimized = lowerName.startsWith('swipess-optimized') ||
      lowerName.startsWith('swipess-portrait-');
  if (alreadyOptimized) return source;
  try {
    // The browser exporter reads metadata and clamps 60s to the real duration.
    return await recutVideoWindowV2(
      source: source,
      start: 0,
      end: 60,
      portraitCrop: true,
      includeOriginalAudio: true,
    );
  } catch (_) {
    return source;
  }
}
