import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

Future<XFile> recutVideoWindowV2({
  required XFile source,
  required double start,
  required double end,
  bool portraitCrop = false,
  double cropX = 0.5,
  XFile? backgroundMusic,
  String? backgroundMusicPreset,
  double musicStart = 0,
  double? musicEnd,
  bool includeOriginalAudio = true,
}) async {
  html.VideoElement? video;
  html.MediaRecorder? recorder;
  html.MediaStream? exportStream;
  Timer? paintTimer;
  String? objectUrl;
  web.AudioContext? audioContext;
  web.AudioBufferSourceNode? musicSource;

  try {
    if (backgroundMusic != null) {
      audioContext = web.AudioContext();
      try {
        await audioContext.resume().toDart;
      } catch (_) {}
    }

    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw StateError('The selected video is empty.');

    final inputBlob = html.Blob(<dynamic>[bytes], 'video/mp4');
    objectUrl = html.Url.createObjectUrlFromBlob(inputBlob);

    video = html.VideoElement()
      ..src = objectUrl
      ..muted = true
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

    try {
      exportStream = canvas.captureStream(30);
    } catch (_) {
      if (portraitCrop) rethrow;
      exportStream = video.captureStream();
    }

    final stream = exportStream!;
    if (stream.getVideoTracks().isEmpty) {
      throw StateError('This browser could not create a video export stream.');
    }

    if (includeOriginalAudio) {
      try {
        final sourceStream = video.captureStream();
        for (final track in sourceStream.getAudioTracks()) {
          stream.addTrack(track);
        }
      } catch (_) {}
    }

    if (backgroundMusic != null && audioContext != null) {
      final musicBytes = await backgroundMusic.readAsBytes();
      if (musicBytes.isNotEmpty) {
        final audioBuffer = await audioContext.decodeAudioData(
          Uint8List.fromList(musicBytes).buffer.toJS,
        ).toDart;
        final duration = audioBuffer.duration.toDouble();
        if (duration > 0.02) {
          final destination = audioContext.createMediaStreamDestination();
          musicSource = audioContext.createBufferSource();
          musicSource.buffer = audioBuffer;

          final safeStart = musicStart.clamp(0.0, math.max(0.0, duration - .02)).toDouble();
          final requestedEnd = musicEnd ?? (safeStart + cutDuration);
          final safeEnd = requestedEnd.clamp(safeStart + .02, duration).toDouble();
          final selectedLength = safeEnd - safeStart;

          if (selectedLength + .03 < cutDuration) {
            musicSource.loop = true;
            musicSource.loopStart = safeStart;
            musicSource.loopEnd = safeEnd;
          }
          musicSource.connect(destination);
          final mixedStream = destination.stream;
          final captureStreamJs = JSObject.fromInteropObject(stream);
          for (final track in mixedStream.getAudioTracks().toDart) {
            // `stream` is still a dart:html MediaStream. Convert the legacy
            // wrapper to its underlying JS object so a package:web track can
            // be attached without unsafe Dart casts between the two bindings.
            captureStreamJs.callMethod<JSAny?>('addTrack'.toJS, track);
          }
        }
      }
    }

    html.MediaRecorder makeRecorder() {
      for (final mime in <String>[
        'video/webm;codecs=vp8,opus',
        'video/webm;codecs=vp8',
        'video/webm',
      ]) {
        try {
          return html.MediaRecorder(stream, <String, dynamic>{'mimeType': mime});
        } catch (_) {}
      }
      return html.MediaRecorder(stream);
    }

    recorder = makeRecorder();
    final chunks = <html.Blob>[];
    final stopped = Completer<void>();

    recorder.addEventListener('dataavailable', (html.Event event) {
      if (event is! html.BlobEvent) return;
      final data = event.data;
      if (data != null && data.size > 0) chunks.add(data);
    });
    recorder.addEventListener('stop', (_) {
      if (!stopped.isCompleted) stopped.complete();
    });

    recorder.start(150);
    await video.play();

    if (musicSource != null && audioContext != null) {
      try {
        await audioContext.resume().toDart;
      } catch (_) {}
      final bufferDuration = (musicSource.buffer?.duration ?? 0).toDouble();
      final safeStart = musicStart.clamp(0.0, math.max(0.0, bufferDuration - .02)).toDouble();
      musicSource.start(0, safeStart);
      musicSource.stop(audioContext.currentTime + cutDuration + .15);
    }

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
    final Uint8List outputBytes;
    if (result is ByteBuffer) {
      outputBytes = Uint8List.view(result);
    } else if (result is Uint8List) {
      outputBytes = result;
    } else {
      throw StateError('Could not prepare the trimmed video.');
    }
    if (outputBytes.isEmpty) throw StateError('The exported video is empty.');

    return XFile.fromData(
      outputBytes,
      mimeType: 'video/webm',
      name:
          'swipess-${portraitCrop ? 'portrait-' : ''}trim-${DateTime.now().millisecondsSinceEpoch}.webm',
    );
  } catch (error) {
    throw StateError('Could not trim this video on this browser. $error');
  } finally {
    paintTimer?.cancel();
    try {
      musicSource?.stop();
    } catch (_) {}
    try {
      await audioContext?.close().toDart;
    } catch (_) {}
    try {
      if (recorder != null && recorder.state != 'inactive') recorder.stop();
    } catch (_) {}
    try {
      for (final track in exportStream?.getTracks() ?? const <html.MediaStreamTrack>[]) {
        track.stop();
      }
    } catch (_) {}
    try {
      video?.pause();
      video?.remove();
    } catch (_) {}
    if (objectUrl != null) html.Url.revokeObjectUrl(objectUrl);
  }
}
