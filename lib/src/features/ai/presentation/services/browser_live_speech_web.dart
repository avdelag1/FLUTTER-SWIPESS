import 'dart:async';
import 'dart:js' as js;

import 'browser_live_speech_stub.dart';

class BrowserLiveSpeech {
  js.JsObject? _recognition;
  bool _active = false;
  bool _intentionalStop = false;
  Timer? _restartTimer;
  String _finalText = '';

  BrowserSpeechTextCallback? _onText;
  BrowserSpeechListeningCallback? _onListening;
  BrowserSpeechErrorCallback? _onError;

  dynamic get _constructor =>
      js.context['SpeechRecognition'] ?? js.context['webkitSpeechRecognition'];

  bool get isSupported => _constructor != null;

  Future<bool> start({
    required BrowserSpeechTextCallback onText,
    required BrowserSpeechListeningCallback onListening,
    required BrowserSpeechErrorCallback onError,
  }) async {
    if (!isSupported) return false;
    await cancel();

    _onText = onText;
    _onListening = onListening;
    _onError = onError;
    _finalText = '';
    _intentionalStop = false;
    _active = true;

    return _startRecognition();
  }

  bool _startRecognition() {
    if (!_active || _intentionalStop || !isSupported) return false;

    try {
      final recognition = js.JsObject(_constructor);
      _recognition = recognition;
      recognition['continuous'] = true;
      recognition['interimResults'] = true;
      recognition['maxAlternatives'] = 1;

      try {
        final navigator = js.context['navigator'] as js.JsObject?;
        final language = navigator?['language']?.toString();
        if (language != null && language.isNotEmpty) {
          recognition['lang'] = language;
        }
      } catch (_) {}

      recognition['onstart'] = js.allowInterop((dynamic _) {
        if (!_active || _intentionalStop) return;
        _onListening?.call(true);
      });

      recognition['onspeechstart'] = js.allowInterop((dynamic _) {
        if (!_active || _intentionalStop) return;
        _onListening?.call(true);
      });

      recognition['onresult'] = js.allowInterop((dynamic rawEvent) {
        if (!_active || _intentionalStop) return;
        try {
          final event = rawEvent as js.JsObject;
          final results = event['results'] as js.JsObject?;
          if (results == null) return;
          final resultIndex = (event['resultIndex'] as num?)?.toInt() ?? 0;
          final length = (results['length'] as num?)?.toInt() ?? 0;

          var interim = '';
          var receivedFinal = false;
          for (var i = resultIndex; i < length; i++) {
            final result = results[i] as js.JsObject?;
            if (result == null) continue;
            final alternative = result[0] as js.JsObject?;
            final transcript = alternative?['transcript']?.toString().trim() ?? '';
            if (transcript.isEmpty) continue;
            final isFinal = result['isFinal'] == true;
            if (isFinal) {
              _finalText = _join(_finalText, transcript);
              receivedFinal = true;
            } else {
              interim = _join(interim, transcript);
            }
          }

          final live = _join(_finalText, interim);
          if (live.isNotEmpty) {
            _onText?.call(live, receivedFinal && interim.isEmpty);
          }
        } catch (_) {}
      });

      recognition['onerror'] = js.allowInterop((dynamic rawEvent) {
        if (!_active || _intentionalStop) return;
        String code = '';
        try {
          code = (rawEvent as js.JsObject)['error']?.toString() ?? '';
        } catch (_) {}
        final lower = code.toLowerCase();

        if (lower.contains('not-allowed') ||
            lower.contains('service-not-allowed') ||
            lower.contains('permission')) {
          _active = false;
          _intentionalStop = true;
          _onListening?.call(false);
          _onError?.call(
            'Microphone permission is blocked. Allow microphone access in Chrome and try again.',
          );
          return;
        }

        if (lower.contains('audio-capture')) {
          _onError?.call('Chrome could not access a microphone on this device.');
          return;
        }

        if (lower.isNotEmpty && !lower.contains('no-speech')) {
          _onError?.call('Voice recognition stopped. Please try again.');
        }
      });

      recognition['onend'] = js.allowInterop((dynamic _) {
        if (!_active || _intentionalStop) {
          _onListening?.call(false);
          return;
        }

        // Chrome periodically closes long recognition sessions. Restart the
        // same invisible native recognizer without changing the Flutter UI.
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(milliseconds: 140), () {
          if (_active && !_intentionalStop) {
            _startRecognition();
          }
        });
      });

      recognition.callMethod('start');
      return true;
    } catch (_) {
      _active = false;
      _onListening?.call(false);
      return false;
    }
  }

  Future<void> stop() async {
    if (!_active && _recognition == null) return;
    _intentionalStop = true;
    _active = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    try {
      _recognition?.callMethod('stop');
      // Give Chrome a brief chance to publish its last partial/final result.
      await Future<void>.delayed(const Duration(milliseconds: 140));
    } catch (_) {}
    _onListening?.call(false);
    _recognition = null;
  }

  Future<void> cancel() async {
    _intentionalStop = true;
    _active = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    try {
      _recognition?.callMethod('abort');
    } catch (_) {}
    _onListening?.call(false);
    _recognition = null;
  }

  static String _join(String left, String right) {
    final a = left.trim();
    final b = right.trim();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a $b';
  }
}
