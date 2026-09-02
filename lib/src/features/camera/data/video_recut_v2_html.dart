import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math' as math;
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
  Timer? paintTimer;
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
    final effectiveEnd =
        (cutStart + cutDuration).clamp(cutStart + 0.2, sourceDuration).toDouble();

    video.currentTime = cutStart;
    if (cutStart > 0.03) {
      await video.onSeeked.first.timeout(const Duration(seconds: 10));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    // Always render the video through a canvas. Mobile Chromium/PWA builds are
    // much more consistent with Canvas.captureStream than Video.captureStream.
    final vw = math.max(1, video.videoWidth).toDouble();
    final vh = math.max(1, video.videoHeight).toDouble();
    final sourceAspect = vw / vh;

    int canvasWidth;
    int canvasHeight;
    if (portraitCrop) {
      canvasWidth = 360;
      canvasHeight = 640;
    } else if (sourceAspect >= 1) {
      canvasWidth = math.min(720, vw.round());
      canvasHeight = math.max(1, (canvasWidth / sourceAspect).round());
    } else {
      canvasHeight = math.min(720, vh.round());
      canvasWidth = math.max(1, (canvasHeight * sourceAspect).round());
    }

    final canvas = html.CanvasElement(width: canvasWidth, height: canvasHeight);
    final ctx = canvas.context2D;
    final canvasStream = canvas.captureStream(30);

    // Keep original audio when this browser supports captureStream on video,
    // but do not fail the whole export when it does not.
    try {
      final sourceStream = video.captureStream();
      for (final track in sourceStream.getAudioTracks()) {
        canvasStream.addTrack(track);
      }
    } catch (_) {}

    void paintFrame() {
      final currentVw = video!.videoWidth.toDouble();
      final currentVh = video.videoHeight.toDouble();
      if (currentVw <= 0 || currentVh <= 0) return;

      if (portraitCrop) {
        const targetAspect = 9 / 16;
        var sw = currentVh * targetAspect;
        var sh = currentVh;
        var sx = (currentVw - sw) * cropX.clamp(0.0, 1.0);
        var sy = 0.0;
        if (sw > currentVw) {
          sw = currentVw;
          sh = currentVw / targetAspect;
          sx = 0;
          sy = (currentVh - sh) / 2;
        }
        ctx.drawImageScaledFromSource(
          video,
          sx,
          sy,
          sw,
          sh,
          0,
          0,
          canvasWidth,
          canvasHeight,
        );
      } else {
        ctx.drawImageScaled(video, 0, 0, canvasWidth, canvasHeight);
      }
    }

    paintFrame();
    paintTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => paintFrame());

    if (canvasStream.getVideoTracks().isEmpty) {
      throw StateError('This browser could not create a video export stream.');
    }

    html.MediaRecorder makeRecorder() {
      for (final mime in <String>[
        'video/webm;codecs=vp8,opus',
        'video/webm;codecs=vp8',
        'video/webm',
      ]) {
        try {
          return html.MediaRecorder(canvasStream, <String, dynamic>{'mimeType': mime});
        } catch (_) {}
      }
      return html.MediaRecorder(canvasStream);
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
      await reachedEnd.future.timeout(
        Duration(milliseconds: ((cutDuration + 4) * 1000).round()),
      );
    } on TimeoutException {
      final remaining = effectiveEnd - video.currentTime;
      if (remaining > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: (remaining * 1000).round()),
        );
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
    if (result is! ByteBuffer) {
      throw StateError('Could not prepare the trimmed video.');
    }

    return XFile.fromData(
      Uint8List.view(result),
      mimeType: 'video/webm',
      name:
          'swipess-${portraitCrop ? 'portrait-' : ''}trim-${DateTime.now().millisecondsSinceEpoch}.webm',
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
