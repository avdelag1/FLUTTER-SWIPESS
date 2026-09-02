import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Desktop/mobile recut via ffmpeg when the binary exists.
Future<XFile> recutVideoWindow({
  required XFile source,
  required double start,
  required double end,
}) async {
  final duration = (end - start).clamp(0.5, 20.0);
  try {
    final version = await Process.run('ffmpeg', ['-version']);
    if (version.exitCode != 0) return source;
    final out =
        '${Directory.systemTemp.path}/swipess_clip_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final result = await Process.run('ffmpeg', [
      '-y',
      '-ss',
      start.toStringAsFixed(2),
      '-i',
      source.path,
      '-t',
      duration.toStringAsFixed(2),
      '-c',
      'copy',
      '-movflags',
      '+faststart',
      out,
    ]);
    if (result.exitCode != 0) return source;
    final file = File(out);
    if (!file.existsSync() || file.lengthSync() < 64) return source;
    return XFile(out, mimeType: 'video/mp4');
  } catch (_) {
    return source;
  }
}
