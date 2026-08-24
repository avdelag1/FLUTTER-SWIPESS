import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/browser_live_speech.dart';
import 'package:record/record.dart';

enum ListenMode { dictation, search, confirmation }

/// One shared microphone coordinator for every SWIPESS AI entry point.
///
/// Web/Chrome uses the browser's native SpeechRecognition API so partial words
/// can appear in the visible Flutter TextField while the user is still talking.
/// It does not mount MediaRecorder/audio platform elements on web. Native apps
/// keep the recorder + Supabase transcription path as the reliable fallback.
class LiveVoiceInput {
  LiveVoiceInput._();

  static final LiveVoiceInput instance = LiveVoiceInput._();

  final VoiceTranscribeRepository _voice = VoiceTranscribeRepository();
  final BrowserLiveSpeech _browser = BrowserLiveSpeech();

  bool _active = false;
  bool _starting = false;
  bool _intentionalStop = false;
  bool _usingBrowser = false;
  Object? _owner;

  String _committed = '';
  String _sessionWords = '';
  String _lastPublished = '';

  Timer? _silenceFinalizeTimer;
  Timer? _browserSilenceTimer;
  Timer? _browserPulseTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _segmentHasSpeech = false;
  bool _finalizing = false;

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
      if (_usingBrowser) return true;
      return _voice.isRecording();
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

    if (_starting) return false;
    _starting = true;

    // IMPORTANT: never start package:record on Flutter Web. The production
    // Chrome failure showed a page-sized gray platform surface while recording.
    // Native browser recognition needs no visible DOM/platform-view surface and
    // provides true interim transcription instead of waiting for a full audio
    // segment to upload.
    if (kIsWeb) {
      try {
        if (!_browser.isSupported) {
          _onError?.call(
            'Live voice typing is not available in this browser. Use Chrome or type your message.',
          );
          _clearSession(keepOwner: false);
          return false;
        }

        _usingBrowser = true;
        _active = true;
        final started = await _browser.start(
          onText: (speech, isFinal) {
            if (!_active || !_usingBrowser || _intentionalStop) return;
            final clean = speech.trim();
            if (clean.isEmpty) return;

            _browserSilenceTimer?.cancel();
            final total = _join(_committed, clean);
            if (total != _lastPublished) {
              _lastPublished = total;
              _onText?.call(total);
            }

            // SpeechRecognition does not expose raw microphone amplitude. Pulse
            // the existing waveform whenever Chrome produces a partial/final
            // transcript so the user still sees an active voice state.
            _onSoundLevel?.call(isFinal ? -24 : -14);
            _browserPulseTimer?.cancel();
            _browserPulseTimer = Timer(const Duration(milliseconds: 170), () {
              if (_active && _usingBrowser) _onSoundLevel?.call(-32);
            });

            _browserSilenceTimer = Timer(silenceBeforeCountdown, () {
              if (!_active || !_usingBrowser || _lastPublished.trim().isEmpty) {
                return;
              }
              _onSoundLevel?.call(0);
              _onSilence?.call();
            });
          },
          onListening: (listening) {
            if (!_usingBrowser) return;
            if (listening) {
              _onListeningChanged?.call(true);
            } else if (!_active || _intentionalStop) {
              _onListeningChanged?.call(false);
            }
          },
          onError: (message) {
            if (!_usingBrowser) return;
            _onError?.call(message);
          },
        );

        if (!started) {
          _active = false;
          _usingBrowser = false;
          _onError?.call(
            'Could not start live voice typing. Check Chrome microphone permission and try again.',
          );
          _clearSession(keepOwner: false);
          return false;
        }

        _onListeningChanged?.call(true);
        return true;
      } catch (_) {
        _active = false;
        _usingBrowser = false;
        _onError?.call(
          'Could not start live voice typing. Check Chrome microphone permission and try again.',
        );
        _clearSession(keepOwner: false);
        return false;
      } finally {
        _starting = false;
      }
    }

    // Native iOS/Android path: record a short segment and use the existing
    // Supabase transcription endpoint. This path is intentionally never used
    // by Flutter Web.
    try {
      final started = await _voice.start();
      if (!started) {
        _onError?.call(
          'Microphone permission is blocked. Allow microphone access and try again.',
        );
        _clearSession(keepOwner: false);
        return false;
      }

      _active = true;
      _segmentHasSpeech = false;
      _listenToAmplitude();
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

  void _listenToAmplitude() {
    unawaited(_amplitudeSubscription?.cancel());
    _amplitudeSubscription = _voice
        .amplitudeStream(interval: const Duration(milliseconds: 90))
        .listen(
          (amplitude) {
            if (!_active || _intentionalStop || _finalizing || _usingBrowser) {
              return;
            }
            final level = amplitude.current.isFinite ? amplitude.current : -60.0;
            _onSoundLevel?.call(level);

            if (level > -45.0) {
              _segmentHasSpeech = true;
              _silenceFinalizeTimer?.cancel();
              _silenceFinalizeTimer = Timer(
                silenceBeforeCountdown,
                () => unawaited(
                  _finalizeSegment(
                    restart: true,
                    triggerSilence: true,
                    forceTranscribe: false,
                  ),
                ),
              );
            }
          },
          onError: (_) {
            if (_active && !_usingBrowser) {
              _onError?.call('Voice recording stopped. Try the microphone again.');
            }
          },
        );
  }

  Future<void> _finalizeSegment({
    required bool restart,
    required bool triggerSilence,
    required bool forceTranscribe,
  }) async {
    if (_usingBrowser) return;
    if (_finalizing) {
      while (_finalizing) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      return;
    }
    if (!_active && !forceTranscribe) return;

    _finalizing = true;
    _silenceFinalizeTimer?.cancel();
    _silenceFinalizeTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _onSoundLevel?.call(0);

    final shouldTranscribe = _segmentHasSpeech || forceTranscribe;
    String text = '';
    try {
      if (shouldTranscribe) {
        text = await _voice.stop();
      } else {
        await _voice.cancel();
      }
    } catch (e) {
      _onError?.call(e.toString());
    }

    if (text.isNotEmpty) {
      final total = _join(_committed, text);
      _sessionWords = text;
      _lastPublished = total;
      _committed = total;
      _onText?.call(total);
    }

    _finalizing = false;

    if (!_active || _intentionalStop) return;

    if (triggerSilence && shouldTranscribe) {
      _onSilence?.call();
    }

    if (restart && _active) {
      try {
        await _voice.start();
        _segmentHasSpeech = false;
        _listenToAmplitude();
      } catch (_) {
        await cancel(owner: _owner);
      }
    }
  }

  Future<void> cancel({Object? owner}) async {
    if (owner != null && !identical(_owner, owner)) return;
    if (!_active && _owner == null) return;

    _intentionalStop = true;
    _active = false;
    _browserSilenceTimer?.cancel();
    _browserPulseTimer?.cancel();
    _silenceFinalizeTimer?.cancel();
    _silenceFinalizeTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _onSoundLevel?.call(0);

    try {
      if (_usingBrowser) {
        await _browser.cancel();
      } else {
        await _voice.cancel();
      }
    } catch (_) {}

    _onListeningChanged?.call(false);
    _clearSession(keepOwner: false);
  }

  Future<void> finish({required Object owner}) async {
    if (!identical(_owner, owner)) return;
    if (!_active && !_usingBrowser) return;

    _intentionalStop = true;
    _browserSilenceTimer?.cancel();
    _browserPulseTimer?.cancel();

    if (_usingBrowser) {
      try {
        await _browser.stop();
      } catch (_) {}
      _active = false;
      _onSoundLevel?.call(0);
      _onListeningChanged?.call(false);
      _clearSession(keepOwner: false);
      return;
    }

    _active = false;
    _onListeningChanged?.call(false);
    _onSoundLevel?.call(0);
    await _finalizeSegment(
      restart: false,
      triggerSilence: false,
      forceTranscribe: true,
    );
    _clearSession(keepOwner: false);
  }

  void _clearSession({required bool keepOwner}) {
    _browserSilenceTimer?.cancel();
    _browserPulseTimer?.cancel();
    _silenceFinalizeTimer?.cancel();
    _browserSilenceTimer = null;
    _browserPulseTimer = null;
    _silenceFinalizeTimer = null;
    _active = false;
    _starting = false;
    _intentionalStop = false;
    _usingBrowser = false;
    _segmentHasSpeech = false;
    _finalizing = false;
    if (!keepOwner) _owner = null;
    _sessionWords = '';
    _lastPublished = '';
    _committed = '';
    _onText = null;
    _onSoundLevel = null;
    _onListeningChanged = null;
    _onSilence = null;
    _onError = null;
  }

  static String _join(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }
}
