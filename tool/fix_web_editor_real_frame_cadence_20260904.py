from pathlib import Path

path = Path('lib/src/features/camera/data/video_recut_v3_html.dart')
text = path.read_text()
old = '''    paintFrame();
    late void Function(num) schedulePaint;
    schedulePaint = (num _) {
      paintFrame();
      paintFrameId = html.window.requestAnimationFrame(schedulePaint);
    };
    paintFrameId = html.window.requestAnimationFrame(schedulePaint);
    exportStream = canvas.captureStream(30);
'''
new = '''    paintFrame();

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
    if (videoJs.hasProperty('requestVideoFrameCallback'.toJS)) {
      late JSFunction onVideoFrame;
      onVideoFrame = ((JSAny? _, JSAny? __) {
        if (video == null) return;
        paintFrame();
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
'''
if new in text:
    print('Web real-frame cadence fix already applied')
elif old in text:
    path.write_text(text.replace(old, new, 1))
    print('Patched web editor to follow real decoded frames')
else:
    raise SystemExit('Expected web frame scheduling block not found')
