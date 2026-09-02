import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Browser recut via `captureStream()` + MediaRecorder.
///
/// Always exports the selected window instead of silently returning the
/// original source when the cut starts at 0 seconds. Returning the original
/// made the editor look successful while the listing preview/upload stayed
/// unchanged.
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

    // captureStream() is unreliable in some browsers when the element uses
    // display:none. Keep it rendered far off-screen instead.
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
    if (!sourceDuration.isFinite || sourceDuration <= 0) {
      throw StateError('Could not read the video duration.');
    }

    final cutStart = start.clamp(0.0, sourceDuration).toDouble();
    final requestedEnd = end.clamp(cutStart + 0.2, sourceDuration).toDouble();
    final cutEnd = requestedEnd.clamp(cutStart + 0.2, sourceDuration).toDouble();
    final cutDuration = (cutEnd - cutStart).clamp(0.2, 60.0).toDouble();
    final effectiveEnd = (cutStart + cutDuration).clamp(cutStart + 0.2, sourceDuration).toDouble();

    video.currentTime = cutStart;
    if ((video.currentTime - cutStart).abs() > 0.05) {
      await video.onSeeked.first.timeout(const Duration(seconds: 8));
    } else {
      // Give the browser one frame to settle at the requested start position.
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

    // Start recording before playback so the first selected frame is not lost.
    recorder.start(200);
    await video.play();

    // Stop from media time rather than only wall-clock time so seeking and
    // browser scheduling do not move the exported window away from the user's
    // selected range.
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
      // A few mobile browsers throttle timeupdate. Fall back to the selected
      // duration, but still export instead of pretending the trim succeeded.
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
