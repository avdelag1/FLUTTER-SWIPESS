import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

import 'browser_live_speech_stub.dart';

/// Web-only implementation of [BrowserLiveSpeech].
///
/// Uses the [window.SwipessSpeech] bridge defined in [web/index.html].
/// The JS bridge enqueues events into [window.SwipessSpeechQueue] (a plain
/// JS array). Dart polls that queue on a tight timer and dispatches events
/// without needing any [allowInterop] closure — which is unreliable in
/// Flutter Web release/minified builds.
class BrowserLiveSpeech {
  bool _active = false;
  bool _intentionalStop = false;
  Timer? _pollTimer;
  Timer? _listeningFalseDebounce;

  BrowserSpeechTextCallback? _onText;
  BrowserSpeechListeningCallback? _onListening;
  BrowserSpeechErrorCallback? _onError;
  BrowserSpeechSilenceCallback? _onSilence;
  BrowserSpeechActivityCallback? _onSpeechActivity;

  static bool get _bridgeReady {
    try {
      return js.context['SwipessSpeech'] != null;
    } catch (_) {
      return false;
    }
  }

  bool get isSupported {
    if (!_bridgeReady) return false;
    try {
      final result = (js.context['SwipessSpeech'] as js.JsObject).callMethod(
        'isSupported',
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  void setLanguage(String langCode) {
    if (!_bridgeReady) return;
    try {
      (js.context['SwipessSpeech'] as js.JsObject).callMethod('setLanguage', [
        langCode,
      ]);
    } catch (_) {}
  }

  Future<bool> start({
    required BrowserSpeechTextCallback onText,
    required BrowserSpeechListeningCallback onListening,
    required BrowserSpeechErrorCallback onError,
    BrowserSpeechSilenceCallback? onSilence,
    BrowserSpeechActivityCallback? onSpeechActivity,
  }) async {
    if (!isSupported) return false;
    await cancel();

    _onText = onText;
    _onListening = onListening;
    _onError = onError;
    _onSilence = onSilence;
    _onSpeechActivity = onSpeechActivity;
    _intentionalStop = false;
    _active = true;

    try {
      (js.context['SwipessSpeech'] as js.JsObject).callMethod('start');
    } catch (e) {
      _active = false;
      _onError?.call('Speech recognition failed to start.');
      return false;
    }

    // Keep resumed speech responsive enough to interrupt 3 -> 2 -> 1.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 35), _poll);
    return true;
  }

  void _poll(Timer _) {
    if (!_active || _intentionalStop) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final queue = js.context['SwipessSpeechQueue'];
      if (queue == null) return;
      final jsQueue = queue as js.JsArray<dynamic>;
      // Drain all pending events.
      while (jsQueue.isNotEmpty) {
        final event = jsQueue.callMethod('shift') as js.JsObject?;
        if (event == null) continue;
        final type = event['type']?.toString() ?? '';
        final payload = event['payload']?.toString() ?? '';
        _dispatch(type, payload);
      }
    } catch (_) {}
  }

  void _dispatch(String type, String payload) {
    if (_intentionalStop) return;
    switch (type) {
      case 'text':
        if (payload.trim().isNotEmpty) {
          _onText?.call(payload.trim(), false);
        }
      case 'listening':
        if (payload == 'true') {
          _listeningFalseDebounce?.cancel();
          _onListening?.call(true);
          return;
        }
        // PWA browsers drop listening briefly between recognition segments.
        _listeningFalseDebounce?.cancel();
        _listeningFalseDebounce = Timer(const Duration(milliseconds: 900), () {
          if (!_active || _intentionalStop) return;
          _onListening?.call(false);
        });
      case 'silence':
        _onSilence?.call();
      case 'speech':
        _onSpeechActivity?.call();
      case 'error':
        _onError?.call(payload);
    }
  }

  Future<void> stop() async {
    _intentionalStop = true;
    _active = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _listeningFalseDebounce?.cancel();
    _listeningFalseDebounce = null;
    try {
      if (_bridgeReady) {
        (js.context['SwipessSpeech'] as js.JsObject).callMethod('stop');
      }
    } catch (_) {}
    _onListening?.call(false);
    _clear();
  }

  Future<void> cancel() async {
    _intentionalStop = true;
    _active = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _listeningFalseDebounce?.cancel();
    _listeningFalseDebounce = null;
    try {
      if (_bridgeReady) {
        (js.context['SwipessSpeech'] as js.JsObject).callMethod('abort');
      }
    } catch (_) {}
    _onListening?.call(false);
    _clear();
  }

  void _clear() {
    _onText = null;
    _onListening = null;
    _onError = null;
    _onSilence = null;
    _onSpeechActivity = null;
    // Drain stale queue so a new session starts clean.
    try {
      (js.context['SwipessSpeechQueue'] as js.JsArray?)?.callMethod('splice', [
        0,
      ]);
    } catch (_) {}
  }
}
