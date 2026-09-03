import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const MethodChannel _videoOptimizer = MethodChannel('swipess/video_optimizer');

Future<XFile> optimizeVideoForUpload(XFile source) async {
  final lowerName = source.name.toLowerCase();
  final alreadyOptimized = lowerName.startsWith('swipess_') ||
      lowerName.startsWith('swipess-optimized') ||
      lowerName.startsWith('swipess-portrait-');
  if (alreadyOptimized) return source;
  if (!Platform.isIOS && !Platform.isAndroid) return source;
  if (source.path.isEmpty || !File(source.path).existsSync()) return source;

  try {
    final response = await _videoOptimizer.invokeMapMethod<String, dynamic>(
      'optimize',
      <String, dynamic>{
        'path': source.path,
        'startMs': 0,
        // -1 means full source duration. The native bridges clamp safely.
        'endMs': -1,
        'portraitCrop': true,
        'cropX': 0.5,
        'includeOriginalAudio': true,
      },
    );
    final path = response?['path']?.toString().trim() ?? '';
    if (path.isEmpty) return source;
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 64) return source;
    return XFile(
      path,
      name: response?['name']?.toString().trim().isNotEmpty == true
          ? response!['name'].toString()
          : 'swipess_${DateTime.now().millisecondsSinceEpoch}.mp4',
      mimeType: 'video/mp4',
      length: file.lengthSync(),
    );
  } catch (_) {
    return source;
  }
}
