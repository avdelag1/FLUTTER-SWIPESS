import 'dart:io';

import 'package:image_picker/image_picker.dart';

Future<XFile> recutVideoWindowV2({
  required XFile source,
  required double start,
  required double end,
  bool portraitCrop = false,
  double cropX = 0.5,
  XFile? backgroundMusic,
  double musicStart = 0,
  double? musicEnd,
  bool includeOriginalAudio = true,
}) async {
  final duration = (end - start).clamp(0.2, 60.0).toDouble();
  try {
    final version = await Process.run('ffmpeg', ['-version']);
    if (version.exitCode != 0) return source;

    final out = '${Directory.systemTemp.path}/swipess_clip_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final hasMusic = backgroundMusic != null && backgroundMusic.path.isNotEmpty;
    final args = <String>[
      '-y',
      '-ss', start.toStringAsFixed(3),
      '-i', source.path,
    ];

    if (hasMusic) {
      args.addAll([
        '-ss', musicStart.clamp(0.0, double.infinity).toStringAsFixed(3),
        '-i', backgroundMusic!.path,
      ]);
    }

    args.addAll(['-t', duration.toStringAsFixed(3)]);

    if (portraitCrop) {
      final xExpr = 'max(0,min(iw-ih*9/16,(iw-ih*9/16)*${cropX.clamp(0.0, 1.0).toStringAsFixed(3)}))';
      args.addAll([
        '-vf', 'crop=ih*9/16:ih:$xExpr:0,scale=720:1280',
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-crf', '23',
      ]);
    } else if (hasMusic) {
      args.addAll([
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-crf', '23',
      ]);
    } else {
      args.addAll(['-c:v', 'copy']);
    }

    if (hasMusic) {
      args.addAll([
        '-map', '0:v:0',
        '-map', '1:a:0?',
        '-c:a', 'aac',
        '-b:a', '192k',
        '-shortest',
      ]);
    } else if (includeOriginalAudio) {
      args.addAll(['-map', '0:v:0', '-map', '0:a:0?', '-c:a', portraitCrop ? 'aac' : 'copy']);
    } else {
      args.add('-an');
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
