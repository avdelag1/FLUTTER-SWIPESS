import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';
import 'package:record/record.dart';

enum ListenMode { dictation, search, confirmation }

class LiveVoiceInput {
  LiveVoiceInput._();

  static final LiveVoiceInput instance = LiveVoiceInput._();

  final VoiceTranscribeRepository _voice = VoiceTranscribeRepository();

  bool _active = false;
  bool _starting = false;
  bool _intentionalStop = false;
  Object? _owner;

  String _committed = '';
  String _sessionWords = '';
  String _lastPublished = '';

  Timer? _silenceFinalizeTimer;
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
    try {
      final started = await _voice.start();
      if (!started) {
        _onError?.call('Microphone permission is blocked. Allow microphone access and try again.');
        _clearSession(keepOwner: false);
        return false;
      }

      _active = true;
      _segmentHasSpeech = false;
      _listenToAmplitude();
      _onListeningChanged?.call(true);
      return true;
    } catch (_) {
      _onError?.call('Could not start voice input. Check microphone permission and try again.');
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
            if (!_active || _intentionalStop || _finalizing) return;
            final level = amplitude.current.isFinite ? amplitude.current : -60.0;
            _onSoundLevel?.call(level);

            if (level > -45.0) {
              final firstSoundOfSegment = !_segmentHasSpeech;
              _segmentHasSpeech = true;
              _silenceFinalizeTimer?.cancel();

              if (firstSoundOfSegment && _lastPublished.isNotEmpty) {
                _onText?.call(_lastPublished);
              }

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
            if (_active) {
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
      final connector = _committed.isNotEmpty &&
              !_committed.endsWith(' ') &&
              !_committed.endsWith('\n')
          ? ' '
          : '';
      _sessionWords = '$_sessionWords$connector$text'.trim();
      final total = '$_committed$connector$text'.trim();
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
    if (owner != null && !isOwnedBy(owner)) return;
    _intentionalStop = true;
    _active = false;
    _onListeningChanged?.call(false);
    _onSoundLevel?.call(0);

    _silenceFinalizeTimer?.cancel();
    _silenceFinalizeTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      await _voice.cancel();
    } catch (_) {}
    _clearSession(keepOwner: false);
  }

  Future<void> finish({required Object owner}) async {
    if (!isOwnedBy(owner)) return;
    _intentionalStop = true;
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
    if (!keepOwner) _owner = null;
    _sessionWords = '';
    _lastPublished = '';
    _onText = null;
    _onSoundLevel = null;
    _onListeningChanged = null;
    _onSilence = null;
    _onError = null;
  }
}
