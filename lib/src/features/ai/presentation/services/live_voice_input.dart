import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One shared voice coordinator for every SWIPESS AI entry point.
///
/// Native apps use platform speech recognition for live partial words. Flutter
/// web uses the app's MediaRecorder + `voice-transcribe` pipeline instead. The
/// web recorder avoids browser speech-recognition DOM/overlay glitches while
/// still exposing live amplitude for the in-field waveform and inserting the
/// transcript back into the same visible field when a segment finishes.
class LiveVoiceInput {
  LiveVoiceInput._();

  static final LiveVoiceInput instance = LiveVoiceInput._();

  final SpeechToText _speech = SpeechToText();
  final VoiceTranscribeRepository _webVoice = VoiceTranscribeRepository();

  bool _initialized = false;
  bool _available = false;
  bool _active = false;
  bool _starting = false;
  bool _intentionalStop = false;
  Object? _owner;

  String _committed = '';
  String _sessionWords = '';
  String _lastPublished = '';

  Timer? _silenceTimer;
  Timer? _restartTimer;
  Timer? _webSilenceFinalizeTimer;
  StreamSubscription<Amplitude>? _webAmplitudeSubscription;
  bool _webSegmentHasSpeech = false;
  bool _webFinalizing = false;

  ValueChanged<String>? _onText;
  ValueChanged<double>? _onSoundLevel;
  ValueChanged<bool>? _onListeningChanged;
  VoidCallback? _onSilence;
  ValueChanged<String>? _onError;
  ListenMode _listenMode = ListenMode.dictation;

  static const silenceBeforeCountdown = Duration(seconds: 4);

  bool get active => _active;
  bool isOwnedBy(Object owner) => _active && identical(_owner, owner);

  Future<bool> start({
    required Object owner,
    required String initialText,
    required ValueChanged<String> onText,
    required VoidCallback onSilence,
    ValueChanged<bool>? onListeningChanged,
    ValueChanged<double>? onSoundLevel,
    ValueChanged<String>? onError,
    ListenMode listenMode = ListenMode.dictation,
  }) async {
    if (_active && !identical(_owner, owner)) {
      await cancel();
    } else if (_active && identical(_owner, owner)) {
      if (kIsWeb) return _webVoice.isRecording();
      return _speech.isListening;
    }

    _owner = owner;
    _onText = onText;
    _onSilence = onSilence;
    _onListeningChanged = onListeningChanged;
    _onSoundLevel = onSoundLevel;
    _onError = onError;
    _listenMode = listenMode;
    _committed = initialText.trim();
    _sessionWords = '';
    _lastPublished = _committed;
    _intentionalStop = false;

    if (kIsWeb) {
      return _startWebRecorder();
    }

    if (!await _ensureInitialized()) {
      _clearSession(keepOwner: false);
      return false;
    }

    _active = true;
    final started = await _listen();
    if (!started) {
      await cancel();
      return false;
    }
    _onListeningChanged?.call(true);
    return true;
  }

  Future<bool> _startWebRecorder() async {
    if (_starting) return false;
    _starting = true;
    try {
      final started = await _webVoice.start();
      if (!started) {
        _onError?.call(
          'Microphone permission is blocked. Allow microphone access and try again.',
        );
        _clearSession(keepOwner: false);
        return false;
      }

      _active = true;
      _webSegmentHasSpeech = false;
      _listenToWebAmplitude();
      _onListeningChanged?.call(true);
      return true;
    } catch (_) {
      _onError?.call(
        'Could not start voice input. Check microphone permission and try again.',
      );
      _clearSession(keepOwner: false);
      return false;
    } finally {
      _starting = false;
    }
  }

  void _listenToWebAmplitude() {
    unawaited(_webAmplitudeSubscription?.cancel());
    _webAmplitudeSubscription = _webVoice
        .amplitudeStream(interval: const Duration(milliseconds: 90))
        .listen(
          (amplitude) {
            if (!_active || _intentionalStop || _webFinalizing) return;
            final level = amplitude.current.isFinite ? amplitude.current : -60.0;
            _onSoundLevel?.call(level);

            // dBFS: values closer to zero are louder. This threshold is loose
            // enough for laptop microphones but high enough to ignore most idle
            // room noise. Manual Stop still transcribes if the threshold misses.
            if (level > -45.0) {
              final firstSoundOfSegment = !_webSegmentHasSpeech;
              _webSegmentHasSpeech = true;
              _webSilenceFinalizeTimer?.cancel();

              // If a 3…2…1 countdown is already showing, re-emitting the current
              // text tells both UIs that speech resumed so they cancel countdown.
              if (firstSoundOfSegment && _lastPublished.isNotEmpty) {
                _onText?.call(_lastPublished);
              }

              _webSilenceFinalizeTimer = Timer(
                silenceBeforeCountdown,
                () => unawaited(
                  _finalizeWebSegment(
                    restart: true,
                    triggerSilence: true,
                    forceTranscribe: false,
                  ),
                ),
              );
            }
          },
          onError: (_) {
            if (_active) {
              _onError?.call('Voice recording stopped. Try the microphone again.');
            }
          },
        );
  }

  Future<void> _finalizeWebSegment({
    required bool restart,
    required bool triggerSilence,
    required bool forceTranscribe,
  }) async {
    if (_webFinalizing) {
      while (_webFinalizing) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      return;
    }
    if (!_active && !forceTranscribe) return;

    _webFinalizing = true;
    _webSilenceFinalizeTimer?.cancel();
    _webSilenceFinalizeTimer = null;
    await _webAmplitudeSubscription?.cancel();
    _webAmplitudeSubscription = null;
    _onSoundLevel?.call(0);

    final shouldTranscribe = _webSegmentHasSpeech || forceTranscribe;
    String text = '';
    try {
      if (shouldTranscribe) {
        text = await _webVoice.stop();
      } else {
        await _webVoice.cancel();
      }
    } on VoiceTranscribeException catch (error) {
      // A silence-only restarted segment can be legitimately too short when the
      // 3…2…1 auto-send fires. Do not turn that into a visible error.
      if (forceTranscribe &&
          !error.message.toLowerCase().contains('too short')) {
        _onError?.call(error.message);
      }
    } catch (_) {
      if (forceTranscribe) {
        _onError?.call('Voice transcription failed — please try again.');
      }
    }

    if (text.trim().isNotEmpty) {
      _committed = _join(_committed, text.trim());
      _lastPublished = _committed;
      _onText?.call(_committed);
    }

    _webSegmentHasSpeech = false;
    _webFinalizing = false;

    if (restart && _active && !_intentionalStop) {
      try {
        final started = await _webVoice.start();
        if (started) {
          _listenToWebAmplitude();
          _onListeningChanged?.call(true);
          if (triggerSilence && text.trim().isNotEmpty) {
            _onSilence?.call();
          }
          return;
        }
      } catch (_) {}
      _onError?.call('Microphone stopped. Tap the mic to continue.');
      _active = false;
      _onListeningChanged?.call(false);
      return;
    }

    if (triggerSilence && text.trim().isNotEmpty) {
      _onSilence?.call();
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: (error) {
          if (!_active) return;
          final message = error.errorMsg.trim();
          if (message.isNotEmpty &&
              !message.contains('error_no_match') &&
              !message.contains('error_speech_timeout')) {
            _onError?.call(_friendlyError(message));
          }
          if (error.permanent) {
            unawaited(cancel());
          } else {
            _scheduleRestart();
          }
        },
      );
    } catch (_) {
      _available = false;
    }
    if (!_available) {
      _onError?.call(
        'Voice input is unavailable. Check microphone permission and try again.',
      );
    }
    return _available;
  }

  Future<bool> _listen() async {
    if (!_active || _starting || !_available) return false;
    if (_speech.isListening) return true;
    _starting = true;
    _sessionWords = '';
    try {
      await _speech.listen(
        onResult: (result) {
          if (!_active) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          _onListeningChanged?.call(true);
          _sessionWords = words;
          _publishTranscript();
          _armSilence();

          if (result.finalResult) {
            _committed = _join(_committed, words);
            _sessionWords = '';
            _lastPublished = _committed;
          }
        },
        onSoundLevelChange: (level) {
          if (_active) _onSoundLevel?.call(level);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: _listenMode,
          autoPunctuation: true,
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(minutes: 2),
        ),
      );

      for (var i = 0; i < 8; i++) {
        if (_speech.isListening) return true;
        if (!_active || _intentionalStop) return false;
        await Future<void>.delayed(const Duration(milliseconds: 75));
      }

      if (_active) {
        _onError?.call(
          'Microphone did not start. Allow microphone access in your browser or device settings, then try again.',
        );
      }
      return false;
    } catch (_) {
      if (_active) {
        _onError?.call(
          'Could not start voice input. Check microphone permission and try again.',
        );
      }
      return false;
    } finally {
      _starting = false;
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('denied') ||
        lower.contains('not-allowed') ||
        lower.contains('not_allowed')) {
      return 'Microphone permission is blocked. Allow microphone access and try again.';
    }
    if (lower.contains('network')) {
      return 'Voice recognition lost its connection. Try again.';
    }
    return 'Voice input stopped: $raw';
  }

  void _publishTranscript() {
    final next = _join(_committed, _sessionWords);
    if (next.isEmpty || next == _lastPublished) return;
    _lastPublished = next;
    _onText?.call(next);
  }

  void _armSilence() {
    _silenceTimer?.cancel();
    if (!_active || _lastPublished.trim().isEmpty) return;
    _silenceTimer = Timer(silenceBeforeCountdown, () {
      if (_active && _lastPublished.trim().isNotEmpty) {
        _onSilence?.call();
      }
    });
  }

  void _handleStatus(String status) {
    if (!_active || _intentionalStop) return;
    if (status == SpeechToText.listeningStatus) {
      _onListeningChanged?.call(true);
      return;
    }
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      if (_sessionWords.isNotEmpty) {
        _committed = _join(_committed, _sessionWords);
        _sessionWords = '';
        _lastPublished = _committed;
      }
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_active || _intentionalStop || kIsWeb) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 180), () {
      if (_active && !_intentionalStop) unawaited(_listen());
    });
  }

  /// Stop listening because the text is about to be sent. The recognized text
  /// remains in the caller's TextEditingController.
  Future<void> finish({Object? owner}) async {
    if (owner != null && !identical(_owner, owner)) return;
    if (!_active) return;
    _intentionalStop = true;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _webSilenceFinalizeTimer?.cancel();

    if (kIsWeb) {
      await _finalizeWebSegment(
        restart: false,
        triggerSilence: false,
        forceTranscribe: true,
      );
      _clearSession(keepOwner: false);
      return;
    }

    try {
      await _speech.stop();
    } catch (_) {}
    _clearSession(keepOwner: false);
  }

  /// Stop microphone capture while preserving recognized text in the caller's
  /// visible field. On web the current MediaRecorder segment is transcribed
  /// before stopping, so tapping the blue Stop button never throws words away.
  Future<void> cancel({Object? owner}) async {
    if (owner != null && !identical(_owner, owner)) return;
    if (!_active && _owner == null) return;
    _intentionalStop = true;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _webSilenceFinalizeTimer?.cancel();

    if (kIsWeb && _active) {
      await _finalizeWebSegment(
        restart: false,
        triggerSilence: false,
        forceTranscribe: true,
      );
      _clearSession(keepOwner: false);
      return;
    }

    try {
      await _speech.cancel();
    } catch (_) {}
    _clearSession(keepOwner: false);
  }

  void _clearSession({required bool keepOwner}) {
    _active = false;
    _starting = false;
    _intentionalStop = false;
    _webFinalizing = false;
    _webSegmentHasSpeech = false;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _webSilenceFinalizeTimer?.cancel();
    unawaited(_webAmplitudeSubscription?.cancel());
    _silenceTimer = null;
    _restartTimer = null;
    _webSilenceFinalizeTimer = null;
    _webAmplitudeSubscription = null;
    _onListeningChanged?.call(false);
    _onSoundLevel?.call(0);
    _onText = null;
    _onSoundLevel = null;
    _onListeningChanged = null;
    _onSilence = null;
    _onError = null;
    _committed = '';
    _sessionWords = '';
    _lastPublished = '';
    if (!keepOwner) _owner = null;
  }

  static String _join(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }
}
