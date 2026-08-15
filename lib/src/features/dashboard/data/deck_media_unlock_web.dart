import 'dart:js_interop';

/// Cap `unlockMediaPlayback` — silent AudioContext tick so later clips
/// can play with sound after the user taps unmute once.
void unlockDeckMedia() {
  try {
    _unlockJs();
  } catch (_) {}
}

@JS('eval')
external JSAny? _eval(JSString code);

void _unlockJs() {
  _eval(
    r'''
    (function () {
      try {
        var AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return;
        if (!window.__swipessDeckAudio) {
          window.__swipessDeckAudio = new AC();
        }
        var ctx = window.__swipessDeckAudio;
        if (ctx.state === "suspended") ctx.resume();
        var buf = ctx.createBuffer(1, 1, 22050);
        var src = ctx.createBufferSource();
        src.buffer = buf;
        src.connect(ctx.destination);
        src.start(0);
      } catch (e) {}
    })();
  '''
        .toJS,
  );
}
