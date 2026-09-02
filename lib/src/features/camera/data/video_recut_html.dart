import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Browser recut via `captureStream()` + MediaRecorder.
Future<XFile> recutVideoWindow({
  required XFile source,
  required double start,
  required double end,
}) async {
  final duration = (end - start).clamp(0.5, 20.0);
  try {
    final video = html.VideoElement()
      ..src = source.path
      ..muted = true
      ..autoplay = false
      ..controls = false
      ..crossOrigin = 'anonymous'
      ..style.display = 'none';
    html.document.body?.append(video);
    await video.onLoadedMetadata.first.timeout(const Duration(seconds: 12));
    video.currentTime = start;
    try {
      await video.onSeeked.first.timeout(const Duration(seconds: 8));
    } catch (_) {}

    html.MediaStream? stream;
    try {
      stream = video.captureStream();
    } catch (_) {
      stream = null;
    }
    if (stream == null) {
      video.remove();
      return source;
    }

    const mime = 'video/webm';
    final recorder = html.MediaRecorder(stream, {'mimeType': mime});
    final chunks = <html.Blob>[];
    final done = Completer<XFile>();
    recorder.addEventListener('dataavailable', (html.Event e) {
      final ev = e as html.BlobEvent;
      if (ev.data != null && ev.data!.size > 0) chunks.add(ev.data!);
    });
    recorder.addEventListener('stop', (html.Event _) {
      () async {
        try {
          final blob = html.Blob(chunks, mime);
          final reader = html.FileReader();
          final loaded = Completer<void>();
          reader.onLoad.listen((_) => loaded.complete());
          reader.readAsArrayBuffer(blob);
          await loaded.future;
          final buf = reader.result as ByteBuffer;
          done.complete(
            XFile.fromData(
              Uint8List.view(buf),
              mimeType: mime,
              name: 'swipess_clip.webm',
            ),
          );
        } catch (_) {
          done.complete(source);
        } finally {
          video.remove();
        }
      }();
    });

    await video.play();
    recorder.start();
    await Future<void>.delayed(
      Duration(milliseconds: (duration * 1000).round()),
    );
    if (recorder.state != 'inactive') recorder.stop();
    video.pause();
    return done.future.timeout(
      const Duration(seconds: 35),
      onTimeout: () {
        video.remove();
        return source;
      },
    );
  } catch (_) {
    return source;
  }
}
