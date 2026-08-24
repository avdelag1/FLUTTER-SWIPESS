import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/browser_live_speech.dart';
import 'package:record/record.dart';

enum ListenMode { dictation, search, confirmation }

/// One shared microphone coordinator for every SWIPESS AI entry point.
///
/// Web/Chrome and native clients share the same recorder/transcription flow so
/// dashboard voice and Intel Core behave identically. The microphone amplitude
/// stream also drives the visible waveform and the hands-free silence timer.
class LiveVoiceInput {
  LiveVoiceInput._();

  static final LiveVoiceInput instance = LiveVoiceInput._();

  VoiceTranscribeRepository? _voice;
  VoiceTranscribeRepository get _nativeVoice =>
      _voice ??= VoiceTranscribeRepository();
  final BrowserLiveSpeech _browser = BrowserLiveSpeech();

  final ValueNotifier<bool> listeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> levelNotifier = ValueNotifier<double>(0);

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

  /// Hands-free flow: four seconds of actual silence, then callers render
  /// their existing 3 -> 2 -> 1 countdown and submit automatically.
  static const silenceBeforeCountdown = Duration(seconds: 4);

  /// `record` reports dBFS. The previous -45 dB gate was sensitive enough for
  /// room noise / laptop fans to continuously reset the silence timer. -36 dB
  /// still catches normal close-range speech while allowing real silence to
  /// complete the four-second timer reliably.
  static const double _speechGateDb = -36.0;

  bool get active => _active;
  bool isOwnedBy(Object owner) => _active && identical(_owner, owner);

  void _publishListening(bool listening) {
    if (listeningNotifier.value != listening) {
      listeningNotifier.value = listening;
    }
    _onListeningChanged?.call(listening);
  }

  void _publishSoundLevel(double rawLevel) {
    _onSoundLevel?.call(rawLevel);
    final normalized = rawLevel <= 0
        ? ((rawLevel + 45) / 45).clamp(0.0, 1.0).toDouble()
        : rawLevel.clamp(0.0, 1.0).toDouble();
    if ((levelNotifier.value - normalized).abs() > .005) {
      levelNotifier.value = normalized;
    }
  }

  void _resetPublishedVoiceState() {
    if (listeningNotifier.value) listeningNotifier.value = false;
    if (levelNotifier.value != 0) levelNotifier.value = 0;
  }

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
      return _nativeVoice.isRecording();
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

    try {
      final started = await _nativeVoice.start();
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
      _publishListening(true);
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
    _amplitudeSubscription = _nativeVoice
        .amplitudeStream(interval: const Duration(milliseconds: 90))
        .listen(
          (amplitude) {
            if (!_active || _intentionalStop || _finalizing || _usingBrowser) {
              return;
            }

            final level = amplitude.current.isFinite
                ? amplitude.current
                : -60.0;
            _publishSoundLevel(level);

            if (level > _speechGateDb) {
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
    _publishSoundLevel(0);

    final shouldTranscribe = _segmentHasSpeech || forceTranscribe;
    String text = '';
    try {
      if (shouldTranscribe) {
        text = await _nativeVoice.stop();
      } else {
        await _nativeVoice.cancel();
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

    // Trigger the UI countdown only after this spoken segment is finalized, so
    // the text is already available when 3 -> 2 -> 1 reaches auto-send.
    if (triggerSilence && shouldTranscribe) {
      _onSilence?.call();
    }

    if (restart && _active) {
      try {
        await _nativeVoice.start();
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
    _publishSoundLevel(0);

    try {
      if (_usingBrowser) {
        await _browser.cancel();
      } else if (_voice != null) {
        await _nativeVoice.cancel();
      }
    } catch (_) {}

    _publishListening(false);
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
      _publishSoundLevel(0);
      _publishListening(false);
      _clearSession(keepOwner: false);
      return;
    }

    _active = false;
    _publishListening(false);
    _publishSoundLevel(0);
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
    _resetPublishedVoiceState();
  }

  static String _join(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }
}
