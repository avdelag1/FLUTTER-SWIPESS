import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<XFile> recutVideoWindowV2({
  required XFile source,
  required double start,
  required double end,
  bool portraitCrop = false,
  double cropX = 0.5,
}) async {
  html.VideoElement? video;
  html.MediaRecorder? recorder;
  html.Timer? paintTimer;
  String? objectUrl;

  try {
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw StateError('The selected video is empty.');
    final inputBlob = html.Blob(<dynamic>[bytes], 'video/mp4');
    objectUrl = html.Url.createObjectUrlFromBlob(inputBlob);

    video = html.VideoElement()
      ..src = objectUrl
      ..muted = false
      ..autoplay = false
      ..controls = false
      ..preload = 'auto';
    video.style
      ..position = 'fixed'
      ..left = '-10000px'
      ..top = '0'
      ..width = '4px'
      ..height = '4px'
      ..opacity = '0.01'
      ..pointerEvents = 'none';
    html.document.body?.append(video);

    await video.onLoadedMetadata.first.timeout(const Duration(seconds: 15));
    final sourceDuration = video.duration.toDouble();
    if (!sourceDuration.isFinite || sourceDuration <= 0.2) {
      throw StateError('Could not read the video duration.');
    }

    final maxStart = sourceDuration - 0.2;
    final cutStart = start.clamp(0.0, maxStart).toDouble();
    final cutEnd = end.clamp(cutStart + 0.2, sourceDuration).toDouble();
    final cutDuration = (cutEnd - cutStart).clamp(0.2, 60.0).toDouble();
    final effectiveEnd = (cutStart + cutDuration).clamp(cutStart + 0.2, sourceDuration).toDouble();

    video.currentTime = cutStart;
    if (cutStart > 0.03) {
      await video.onSeeked.first.timeout(const Duration(seconds: 10));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    html.MediaStream stream;
    if (portraitCrop) {
      final canvas = html.CanvasElement(width: 360, height: 640);
      final ctx = canvas.context2D;
      final sourceStream = video.captureStream();
      final canvasStream = canvas.captureStream(30);
      for (final track in sourceStream.getAudioTracks()) {
        canvasStream.addTrack(track);
      }
      stream = canvasStream;

      void paintFrame() {
        final vw = video!.videoWidth.toDouble();
        final vh = video.videoHeight.toDouble();
        if (vw <= 0 || vh <= 0) return;
        final targetAspect = 9 / 16;
        var sw = vh * targetAspect;
        var sh = vh;
        var sx = (vw - sw) * cropX.clamp(0.0, 1.0);
        var sy = 0.0;
        if (sw > vw) {
          sw = vw;
          sh = vw / targetAspect;
          sx = 0;
          sy = (vh - sh) / 2;
        }
        ctx.drawImageScaledFromSource(video, sx, sy, sw, sh, 0, 0, 360, 640);
      }
      paintFrame();
      paintTimer = html.Timer.periodic(const Duration(milliseconds: 33), (_) => paintFrame());
    } else {
      stream = video.captureStream();
    }

    if (stream.getVideoTracks().isEmpty) {
      throw StateError('This browser could not capture the selected video.');
    }

    html.MediaRecorder makeRecorder() {
      try {
        return html.MediaRecorder(stream, <String, dynamic>{'mimeType': 'video/webm;codecs=vp8,opus'});
      } catch (_) {
        try {
          return html.MediaRecorder(stream, <String, dynamic>{'mimeType': 'video/webm'});
        } catch (_) {
          return html.MediaRecorder(stream);
        }
      }
    }

    recorder = makeRecorder();
    final chunks = <html.Blob>[];
    final stopped = Completer<void>();
    recorder.addEventListener('dataavailable', (html.Event event) {
      final blobEvent = event as html.BlobEvent;
      final data = blobEvent.data;
      if (data != null && data.size > 0) chunks.add(data);
    });
    recorder.addEventListener('stop', (_) {
      if (!stopped.isCompleted) stopped.complete();
    });

    recorder.start(150);
    await video.play();

    final reachedEnd = Completer<void>();
    late StreamSubscription<html.Event> sub;
    sub = video.onTimeUpdate.listen((_) {
      if (!reachedEnd.isCompleted && video!.currentTime >= effectiveEnd - 0.035) {
        reachedEnd.complete();
      }
    });
    try {
      await reachedEnd.future.timeout(Duration(milliseconds: ((cutDuration + 4) * 1000).round()));
    } on TimeoutException {
      final remaining = effectiveEnd - video.currentTime;
      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: (remaining * 1000).round()));
      }
    } finally {
      await sub.cancel();
    }

    video.pause();
    paintTimer?.cancel();
    if (recorder.state != 'inactive') recorder.stop();
    await stopped.future.timeout(const Duration(seconds: 10));

    if (chunks.isEmpty) throw StateError('No trimmed video data was produced.');
    final outputBlob = html.Blob(chunks, 'video/webm');
    final reader = html.FileReader();
    final loaded = Completer<void>();
    reader.onLoad.listen((_) {
      if (!loaded.isCompleted) loaded.complete();
    });
    reader.readAsArrayBuffer(outputBlob);
    await loaded.future.timeout(const Duration(seconds: 12));
    final result = reader.result;
    if (result is! ByteBuffer) throw StateError('Could not prepare the trimmed video.');

    return XFile.fromData(
      Uint8List.view(result),
      mimeType: 'video/webm',
      name: 'swipess-${portraitCrop ? 'portrait-' : ''}trim-${DateTime.now().millisecondsSinceEpoch}.webm',
    );
  } catch (error) {
    throw StateError('Could not trim this video on this browser. $error');
  } finally {
    paintTimer?.cancel();
    try {
      if (recorder != null && recorder.state != 'inactive') recorder.stop();
    } catch (_) {}
    try {
      video?.pause();
      video?.remove();
    } catch (_) {}
    if (objectUrl != null) html.Url.revokeObjectUrl(objectUrl);
  }
}
