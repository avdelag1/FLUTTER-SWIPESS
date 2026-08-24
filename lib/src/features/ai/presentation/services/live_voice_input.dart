import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One shared speech recognizer for every SWIPESS AI entry point.
///
/// Platform speech recognizers are intentionally single-session resources. This
/// coordinator guarantees that the dashboard search bar and Intel Core never
/// compete for the microphone, keeps partial text live in the visible field,
/// restarts short Android recognition windows, and emits a four-second silence
/// signal that the UI turns into its 3…2…1 hands-free send countdown.
class LiveVoiceInput {
  LiveVoiceInput._();

  static final LiveVoiceInput instance = LiveVoiceInput._();

  final SpeechToText _speech = SpeechToText();

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
      return true;
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

    if (!await _ensureInitialized()) {
      _clearSession(keepOwner: false);
      return false;
    }

    _active = true;
    _onListeningChanged?.call(true);
    final started = await _listen();
    if (!started) {
      await cancel();
      return false;
    }
    return true;
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
            _onError?.call(message);
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
      _onError?.call('Speech recognition is not available on this device.');
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
      return _speech.isListening || _active;
    } catch (error) {
      if (_active) {
        _onError?.call('Could not start voice input.');
        _scheduleRestart();
      }
      return false;
    } finally {
      _starting = false;
    }
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
      // Some platforms finalize recognition after only a short pause. Commit
      // the latest partial phrase before restarting so dictation stays seamless.
      if (_sessionWords.isNotEmpty) {
        _committed = _join(_committed, _sessionWords);
        _sessionWords = '';
        _lastPublished = _committed;
      }
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_active || _intentionalStop) return;
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
    try {
      await _speech.stop();
    } catch (_) {}
    _clearSession(keepOwner: false);
  }

  /// Cancel microphone capture without changing whatever text is already in the
  /// visible composer/search field.
  Future<void> cancel({Object? owner}) async {
    if (owner != null && !identical(_owner, owner)) return;
    if (!_active && _owner == null) return;
    _intentionalStop = true;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    try {
      await _speech.cancel();
    } catch (_) {}
    _clearSession(keepOwner: false);
  }

  void _clearSession({required bool keepOwner}) {
    _active = false;
    _starting = false;
    _intentionalStop = false;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _silenceTimer = null;
    _restartTimer = null;
    _onListeningChanged?.call(false);
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
