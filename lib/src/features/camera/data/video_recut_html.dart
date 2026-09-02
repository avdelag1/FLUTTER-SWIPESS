import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Browser recut via `captureStream()` + MediaRecorder.
///
/// Always exports the selected window instead of silently returning the
/// original source. The listing preview therefore receives the exact clip the
/// user selected in the trim editor.
Future<XFile> recutVideoWindow({
  required XFile source,
  required double start,
  required double end,
}) async {
  html.VideoElement? video;
  html.MediaRecorder? recorder;

  try {
    video = html.VideoElement()
      ..src = source.path
      ..muted = true
      ..autoplay = false
      ..controls = false
      ..preload = 'auto'
      ..crossOrigin = 'anonymous';

    // captureStream() can fail when the element is display:none on mobile
    // browsers. Keep it technically rendered but far outside the viewport.
    video.style
      ..position = 'fixed'
      ..left = '-10000px'
      ..top = '0'
      ..width = '2px'
      ..height = '2px'
      ..opacity = '0'
      ..pointerEvents = 'none';

    html.document.body?.append(video);
    await video.onLoadedMetadata.first.timeout(const Duration(seconds: 12));

    final sourceDuration = video.duration.toDouble();
    if (!sourceDuration.isFinite || sourceDuration <= 0.2) {
      throw StateError('Could not read a usable video duration.');
    }

    final maxStart = sourceDuration - 0.2;
    final cutStart = start.clamp(0.0, maxStart).toDouble();
    final cutEnd = end.clamp(cutStart + 0.2, sourceDuration).toDouble();
    final cutDuration = (cutEnd - cutStart).clamp(0.2, 60.0).toDouble();
    final effectiveEnd = (cutStart + cutDuration)
        .clamp(cutStart + 0.2, sourceDuration)
        .toDouble();

    video.currentTime = cutStart;
    if (cutStart > 0.05) {
      // Do not trust currentTime immediately after assignment. Wait until the
      // browser confirms the seek before recording the selected window.
      await video.onSeeked.first.timeout(const Duration(seconds: 8));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    html.MediaStream? stream;
    try {
      stream = video.captureStream();
    } catch (_) {
      stream = null;
    }
    if (stream == null) {
      throw StateError('This browser could not create the selected video cut.');
    }

    const mime = 'video/webm';
    recorder = html.MediaRecorder(stream, {'mimeType': mime});
    final chunks = <html.Blob>[];
    final stopped = Completer<void>();

    recorder.addEventListener('dataavailable', (html.Event e) {
      final event = e as html.BlobEvent;
      final data = event.data;
      if (data != null && data.size > 0) chunks.add(data);
    });
    recorder.addEventListener('stop', (_) {
      if (!stopped.isCompleted) stopped.complete();
    });

    // Record before starting playback so the first chosen frame is included.
    recorder.start(200);
    await video.play();

    // Use media time so browser scheduling does not shift the selected window.
    final reachedEnd = Completer<void>();
    late StreamSubscription<html.Event> timeSub;
    timeSub = video.onTimeUpdate.listen((_) {
      if (video == null || reachedEnd.isCompleted) return;
      if (video.currentTime >= effectiveEnd - 0.04) reachedEnd.complete();
    });

    try {
      await reachedEnd.future.timeout(
        Duration(milliseconds: ((cutDuration + 5) * 1000).round()),
      );
    } on TimeoutException {
      // Some mobile browsers throttle timeupdate. Finish the remaining media
      // time instead of returning the untrimmed source.
      final remaining = effectiveEnd - video.currentTime;
      if (remaining > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: (remaining * 1000).round()),
        );
      }
    } finally {
      await timeSub.cancel();
    }

    if (recorder.state != 'inactive') recorder.stop();
    video.pause();
    await stopped.future.timeout(const Duration(seconds: 8));

    if (chunks.isEmpty) {
      throw StateError('The browser did not return the trimmed video data.');
    }

    final blob = html.Blob(chunks, mime);
    final reader = html.FileReader();
    final loaded = Completer<void>();
    reader.onLoad.listen((_) {
      if (!loaded.isCompleted) loaded.complete();
    });
    reader.readAsArrayBuffer(blob);
    await loaded.future.timeout(const Duration(seconds: 10));
    final result = reader.result;
    if (result is! ByteBuffer) {
      throw StateError('Could not prepare the trimmed video preview.');
    }

    return XFile.fromData(
      Uint8List.view(result),
      mimeType: mime,
      name: 'swipess-trim-${DateTime.now().millisecondsSinceEpoch}.webm',
    );
  } catch (error) {
    throw StateError('Could not trim this video. Please try again. ($error)');
  } finally {
    try {
      if (recorder != null && recorder.state != 'inactive') recorder.stop();
    } catch (_) {}
    try {
      video?.pause();
      video?.remove();
    } catch (_) {}
  }
}
