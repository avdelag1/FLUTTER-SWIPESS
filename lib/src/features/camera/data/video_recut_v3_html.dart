import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

String _sourceMime(XFile source) {
  final mime = source.mimeType?.trim().toLowerCase() ?? '';
  if (mime.startsWith('video/')) return mime;
  final lower = source.name.toLowerCase();
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  return 'video/mp4';
}

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
  int? paintFrameId;
  String? objectUrl;
  web.AudioContext? audioContext;
  web.AudioBufferSourceNode? musicSource;
  JSObject? mediaElementSource;
  var presentedFrames = 0;
  var usesDecodedFrameClock = false;

  try {
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw StateError('The selected video is empty.');

    final inputBlob = html.Blob(<dynamic>[bytes], _sourceMime(source));
    objectUrl = html.Url.createObjectUrlFromBlob(inputBlob);

    video = html.VideoElement()
      ..src = objectUrl
      ..muted = true
      ..autoplay = false
      ..controls = false
      ..preload = 'auto';
    video.style
      ..position = 'fixed'
      ..left = '0'
      ..top = '0'
      ..width = '2px'
      ..height = '2px'
      ..opacity = '0.01'
      ..pointerEvents = 'none';
    video.style
      ..setProperty('z-index', '2147483647')
      ..setProperty('transform', 'translateZ(0)')
      ..setProperty('will-change', 'transform');
    video.setAttribute('playsinline', 'true');
    video.setAttribute('webkit-playsinline', 'true');
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
    final effectiveEnd = (cutStart + cutDuration)
        .clamp(cutStart + 0.2, sourceDuration)
        .toDouble();

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
      // Browser/PWA uploads use a mobile delivery rendition. 720x1280 is
      // still crisp on phone displays while cutting pixel decode work by more
      // than half versus 1080x1920, which matters on quick-filter feeds.
      canvasWidth = 720;
      canvasHeight = 1280;
    } else if (sourceAspect >= 1) {
      canvasWidth = math.min(960, vw.round());
      canvasHeight = math.max(1, (canvasWidth / sourceAspect).round());
    } else {
      canvasHeight = math.min(960, vh.round());
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

    // IMPORTANT: never drive the export from requestAnimationFrame while also
    // forcing canvas.captureStream(30). On Safari/PWA the video decoder can
    // present a genuinely new source frame far less often than the display
    // refresh callback. Re-drawing the same decoded frame on every rAF tick was
    // how listing exports ended up with ~5-8 real motion frames/sec while the
    // container advertised a much higher rate.
    //
    // requestVideoFrameCallback fires when the VIDEO presents a new decoded
    // frame, so the canvas changes only for genuine source motion. captureStream
    // is intentionally left without a forced fps and follows those canvas
    // updates. This preserves 24/25/30/50/60fps source cadence instead of
    // inventing an unrelated 30fps recording clock.
    final videoJs = JSObject.fromInteropObject(video);
    if (videoJs.hasProperty('requestVideoFrameCallback'.toJS).toDart) {
      usesDecodedFrameClock = true;
      late JSFunction onVideoFrame;
      onVideoFrame = ((JSAny? _, JSAny? __) {
        if (video == null) return;
        paintFrame();
        presentedFrames += 1;
        if (video!.currentTime < effectiveEnd - 0.01) {
          videoJs.callMethod<JSAny?>(
            'requestVideoFrameCallback'.toJS,
            onVideoFrame,
          );
        }
      }).toJS;
      videoJs.callMethod<JSAny?>(
        'requestVideoFrameCallback'.toJS,
        onVideoFrame,
      );
    } else {
      // Compatibility fallback for older browsers. Modern Safari/Chromium use
      // the decoded-frame path above.
      late void Function(num) schedulePaint;
      schedulePaint = (num _) {
        paintFrame();
        paintFrameId = html.window.requestAnimationFrame(schedulePaint);
      };
      paintFrameId = html.window.requestAnimationFrame(schedulePaint);
    }
    exportStream = canvas.captureStream();
    final stream = exportStream!;
    if (stream.getVideoTracks().isEmpty) {
      throw StateError('This browser could not create a video export stream.');
    }

    // Use WebAudio instead of HTMLMediaElement.captureStream. Safari/iPhone do
    // not expose media-element captureStream, but they do support MediaRecorder,
    // AudioContext and canvas capture. Routing the media element into a stream
    // destination preserves the original listing audio on iOS PWA as well.
    if (includeOriginalAudio || backgroundMusic != null) {
      audioContext = web.AudioContext();
      try {
        await audioContext.resume().toDart;
      } catch (_) {}
    }

    if (includeOriginalAudio && audioContext != null) {
      try {
        final destination = audioContext.createMediaStreamDestination();
        final contextJs = JSObject.fromInteropObject(audioContext);
        final videoJs = JSObject.fromInteropObject(video);
        mediaElementSource = contextJs.callMethod<JSObject>(
          'createMediaElementSource'.toJS,
          videoJs,
        );
        mediaElementSource!.callMethod<JSAny?>(
          'connect'.toJS,
          JSObject.fromInteropObject(destination),
        );
        video.muted = false;
        video.volume = 1;
        final captureStreamJs = JSObject.fromInteropObject(stream);
        for (final track in destination.stream.getAudioTracks().toDart) {
          captureStreamJs.callMethod<JSAny?>('addTrack'.toJS, track);
        }
      } catch (_) {
        // If the browser cannot preserve the original audio, do not silently
        // publish a muted replacement. Returning the source keeps user media
        // intact and lets the uploader fall back safely.
        return source;
      }
    }

    if (backgroundMusic != null && audioContext != null) {
      final musicBytes = await backgroundMusic.readAsBytes();
      if (musicBytes.isNotEmpty) {
        final audioBuffer = await audioContext
            .decodeAudioData(Uint8List.fromList(musicBytes).buffer.toJS)
            .toDart;
        final duration = audioBuffer.duration.toDouble();
        if (duration > 0.02) {
          final destination = audioContext.createMediaStreamDestination();
          musicSource = audioContext.createBufferSource();
          musicSource.buffer = audioBuffer;

          final safeStart = musicStart
              .clamp(0.0, math.max(0.0, duration - .02))
              .toDouble();
          final requestedEnd = musicEnd ?? (safeStart + cutDuration);
          final safeEnd = requestedEnd
              .clamp(safeStart + .02, duration)
              .toDouble();
          final selectedLength = safeEnd - safeStart;
          if (selectedLength + .03 < cutDuration) {
            musicSource.loop = true;
            musicSource.loopStart = safeStart;
            musicSource.loopEnd = safeEnd;
          }
          musicSource.connect(destination);
          final captureStreamJs = JSObject.fromInteropObject(stream);
          for (final track in destination.stream.getAudioTracks().toDart) {
            captureStreamJs.callMethod<JSAny?>('addTrack'.toJS, track);
          }
        }
      }
    }

    var selectedMime = '';
    html.MediaRecorder makeRecorder() {
      // Safari/iOS prefers MP4; Chromium/Firefox commonly prefer WebM. Trying
      // MP4 first gives Apple devices a native H.264/AAC path when available.
      for (final mime in <String>[
        'video/mp4;codecs=avc1.42E01E,mp4a.40.2',
        'video/mp4',
        'video/webm;codecs=vp8,opus',
        'video/webm;codecs=vp8',
        'video/webm',
      ]) {
        try {
          final candidate = html.MediaRecorder(stream, <String, dynamic>{
            'mimeType': mime,
            'videoBitsPerSecond': 4800000,
          });
          selectedMime = mime;
          return candidate;
        } catch (_) {}
      }
      selectedMime = 'video/webm';
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
      final safeStart = musicStart
          .clamp(0.0, math.max(0.0, bufferDuration - .02))
          .toDouble();
      musicSource.start(0, safeStart);
      musicSource.stop(audioContext.currentTime + cutDuration + .15);
    }

    final reachedEnd = Completer<void>();
    late StreamSubscription<html.Event> sub;
    sub = video.onTimeUpdate.listen((_) {
      if (!reachedEnd.isCompleted &&
          video!.currentTime >= effectiveEnd - 0.035) {
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
    if (paintFrameId != null) html.window.cancelAnimationFrame(paintFrameId!);
    paintFrameId = null;
    if (recorder.state != 'inactive') recorder.stop();
    await stopped.future.timeout(const Duration(seconds: 10));
    if (chunks.isEmpty)
      throw StateError('No optimized video data was produced.');

    if (usesDecodedFrameClock && cutDuration >= 1.5) {
      final realFps = presentedFrames / cutDuration;
      if (realFps < 12) {
        throw StateError(
          'This browser could not preserve smooth motion for this edit. '
          'Choose KEEP FULL VIDEO or retry the edit.',
        );
      }
    }

    final outputMime = selectedMime.contains('mp4')
        ? 'video/mp4'
        : 'video/webm';
    final extension = outputMime == 'video/mp4' ? 'mp4' : 'webm';
    final outputBlob = html.Blob(chunks, outputMime);
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
      throw StateError('Could not prepare the optimized video.');
    }
    if (outputBytes.isEmpty) throw StateError('The exported video is empty.');

    return XFile.fromData(
      outputBytes,
      mimeType: outputMime,
      name:
          'swipess-${portraitCrop ? 'portrait-' : ''}optimized-${DateTime.now().millisecondsSinceEpoch}.$extension',
      length: outputBytes.lengthInBytes,
    );
  } catch (error) {
    throw StateError('Could not optimize this video on this browser. $error');
  } finally {
    if (paintFrameId != null) html.window.cancelAnimationFrame(paintFrameId!);
    paintFrameId = null;
    try {
      musicSource?.stop();
    } catch (_) {}
    mediaElementSource = null;
    try {
      await audioContext?.close().toDart;
    } catch (_) {}
    try {
      if (recorder != null && recorder.state != 'inactive') recorder.stop();
    } catch (_) {}
    try {
      for (final track
          in exportStream?.getTracks() ?? const <html.MediaStreamTrack>[]) {
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
