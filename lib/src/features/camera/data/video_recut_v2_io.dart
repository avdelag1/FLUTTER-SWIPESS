import 'dart:io';

import 'package:image_picker/image_picker.dart';

Future<XFile> recutVideoWindowV2({
  required XFile source,
  required double start,
  required double end,
  bool portraitCrop = false,
  double cropX = 0.5,
}) async {
  final duration = (end - start).clamp(0.2, 60.0).toDouble();
  try {
    final version = await Process.run('ffmpeg', ['-version']);
    if (version.exitCode != 0) return source;
    final out = '${Directory.systemTemp.path}/swipess_clip_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final args = <String>[
      '-y',
      '-ss', start.toStringAsFixed(3),
      '-i', source.path,
      '-t', duration.toStringAsFixed(3),
    ];
    if (portraitCrop) {
      final xExpr = 'max(0,min(iw-ih*9/16,(iw-ih*9/16)*${cropX.clamp(0.0, 1.0).toStringAsFixed(3)}))';
      args.addAll([
        '-vf', 'crop=ih*9/16:ih:$xExpr:0,scale=720:1280',
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-crf', '23',
        '-c:a', 'aac',
      ]);
    } else {
      args.addAll(['-c', 'copy']);
    }
    args.addAll(['-movflags', '+faststart', out]);
    final result = await Process.run('ffmpeg', args);
    if (result.exitCode != 0) return source;
    final file = File(out);
    if (!file.existsSync() || file.lengthSync() < 64) return source;
    return XFile(out, mimeType: 'video/mp4');
  } catch (_) {
    return source;
  }
}
