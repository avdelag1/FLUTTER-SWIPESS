import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/browser_live_speech.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum ListenMode { dictation, search, confirmation }

/// Shared microphone coordinator for every SWIPESS AI entry point.
///
/// Web uses browser speech recognition. Native iOS/Android uses the platform
/// speech recognizer through `speech_to_text`, including partial results, so
/// words appear in the composer while the user is still speaking.
///
/// The microphone stays armed across recognizer segment boundaries. A short
/// silence starts the caller's 3 -> 2 -> 1 flow without deliberately killing
/// the native recognizer. If the OS ends a recognition segment anyway, SWIPESS
/// restarts it quickly and keeps extending the same transcript.
class LiveVoiceInput {
  LiveVoiceInput._();

  static final LiveVoiceInput instance = LiveVoiceInput._();

  final BrowserLiveSpeech _browser = BrowserLiveSpeech();
  final stt.SpeechToText _nativeSpeech = stt.SpeechToText();

  final ValueNotifier<bool> listeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> levelNotifier = ValueNotifier<double>(0);

  bool _active = false;
  bool _starting = false;
  bool _intentionalStop = false;
  bool _usingBrowser = false;
  bool _nativeInitialized = false;
  bool _nativeRestarting = false;
  bool _restartAfterSilence = true;
  int _nativeTransientFailures = 0;
  Object? _owner;

  String _committed = '';
  String _lastPublished = '';
  String _nativeSessionText = '';
  String _languageCode = '';
  bool _segmentHasSpeech = false;
  bool _silenceDeliveredForSegment = false;

  Timer? _browserSilenceTimer;
  Timer? _nativeSilenceTimer;
  Timer? _nativeRestartTimer;

  ValueChanged<String>? _onText;
  ValueChanged<double>? _onSoundLevel;
  ValueChanged<bool>? _onListeningChanged;
  VoidCallback? _onSilence;
  VoidCallback? _onSpeechActivity;
  ValueChanged<String>? _onError;
  ListenMode _listenMode = ListenMode.dictation;

  static const silenceBeforeCountdown = Duration(milliseconds: 2200);
  static const _nativeKeepAlivePause = Duration(seconds: 12);
  static const _nativeRestartDelay = Duration(milliseconds: 120);

  Duration get _effectiveSilenceBeforeCountdown =>
      kIsWeb ? const Duration(milliseconds: 1500) : silenceBeforeCountdown;

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
        : (rawLevel / 10).clamp(0.0, 1.0).toDouble();
    if ((levelNotifier.value - normalized).abs() > .005) {
      levelNotifier.value = normalized;
    }
  }

  void _resetPublishedVoiceState() {
    if (listeningNotifier.value) listeningNotifier.value = false;
    if (levelNotifier.value != 0) levelNotifier.value = 0;
  }

  void setLanguage(String langCode) {
    _languageCode = langCode.trim();
    if (kIsWeb) _browser.setLanguage(_languageCode);
  }

  Future<bool> start({
    required Object owner,
    required String initialText,
    required ValueChanged<String> onText,
    required VoidCallback onSilence,
    VoidCallback? onSpeechActivity,
    ValueChanged<bool>? onListeningChanged,
    ValueChanged<double>? onSoundLevel,
    ValueChanged<String>? onError,
    ListenMode listenMode = ListenMode.dictation,
    String? languageCode,
    bool restartAfterSilence = true,
  }) async {
    if (languageCode != null) setLanguage(languageCode);

    if (_active && !identical(_owner, owner)) {
      await cancel();
    } else if (_active && identical(_owner, owner)) {
      return true;
    }

    if (_starting) return false;
    _starting = true;

    _owner = owner;
    _onText = onText;
    _onSilence = onSilence;
    _onSpeechActivity = onSpeechActivity;
    _onListeningChanged = onListeningChanged;
    _onSoundLevel = onSoundLevel;
    _onError = onError;
    _listenMode = listenMode;
    // Dashboard AI and Intel Core explicitly pass true. Keep the microphone
    // armed across short native/browser segment boundaries while composing.
    _restartAfterSilence = restartAfterSilence;
    _committed = initialText.trim();
    _lastPublished = _committed;
    _nativeSessionText = '';
    _segmentHasSpeech = false;
    _silenceDeliveredForSegment = false;
    _nativeTransientFailures = 0;
    _intentionalStop = false;

    try {
      if (kIsWeb && _browser.isSupported) {
        _usingBrowser = true;
        _active = true;
        final started = await _browser.start(
          onText: (speech, _) {
            if (!_active || _intentionalStop || !_usingBrowser) return;
            final clean = speech.trim();
            if (clean.isEmpty) return;
            _segmentHasSpeech = true;
            _silenceDeliveredForSegment = false;
            final total = _join(_committed, clean);
            _committed = total;
            if (total != _lastPublished) {
              _lastPublished = total;
              _onText?.call(total);
            }
            _armBrowserSilence();
          },
          onSilence: () {
            if (!_active || _intentionalStop || !_usingBrowser) return;
            // Browser segment-end is only a hint. Keep a Dart-side silence
            // window so ordinary pauses do not chop a sentence.
            _armBrowserSilence();
          },
          onSpeechActivity: () {
            if (!_active || _intentionalStop || !_usingBrowser) return;
            _browserSilenceTimer?.cancel();
            _browserSilenceTimer = null;
            _segmentHasSpeech = true;
            _silenceDeliveredForSegment = false;
            _onSpeechActivity?.call();
          },
          onListening: (listening) {
            if (!_active || _intentionalStop) return;
            _publishListening(listening);
          },
          onError: (message) {
            if (!_active || _intentionalStop) return;
            _onError?.call(message);
          },
        );
        if (started) {
          _publishListening(true);
          _armBrowserSilence();
          return true;
        }
        _usingBrowser = false;
        _active = false;
      }

      final ready = await _initializeNative();
      if (!ready) {
        _onError?.call(
          'Speech recognition is unavailable. Allow microphone and speech recognition access, then try again.',
        );
        _clearSession(keepOwner: false);
        return false;
      }

      _usingBrowser = false;
      _active = true;
      await _startNativeListen();
      return _active;
    } catch (_) {
      _onError?.call(
        'Could not start voice input. Check microphone and speech recognition permission and try again.',
      );
      _clearSession(keepOwner: false);
      return false;
    } finally {
      _starting = false;
    }
  }

  Future<bool> _initializeNative() async {
    if (_nativeInitialized && _nativeSpeech.isAvailable) {
      return _ensureNativePermission();
    }

    _nativeInitialized = await _nativeSpeech.initialize(
      onStatus: _handleNativeStatus,
      onError: (error) => _handleNativeError(error.errorMsg),
    );
    if (!_nativeInitialized) return false;
    return _ensureNativePermission();
  }

  void _handleNativeError(String rawMessage) {
    if (!_active || _intentionalStop || _usingBrowser) return;
    final msg = rawMessage.toLowerCase();

    if (msg.contains('no_match') ||
        msg.contains('speech_timeout') ||
        msg.contains('timeout')) {
      _finishNativeSegmentAndRestart(
        restartDelay: const Duration(milliseconds: 160),
      );
      return;
    }

    if (msg.contains('permission') || msg.contains('not authorized')) {
      _nativeInitialized = false;
      _onError?.call(
        'Microphone access is required. Open Settings → Swipess and allow Microphone and Speech Recognition.',
      );
      return;
    }

    const transientMarkers = <String>[
      'busy',
      'client',
      'network',
      'server',
      'audio',
      'recognizer',
      'retry',
      'temporarily',
    ];
    final recoverable =
        transientMarkers.any(msg.contains) || !_nativeSpeech.isListening;
    if (recoverable && _nativeTransientFailures < 8) {
      _nativeTransientFailures += 1;
      _finishNativeSegmentAndRestart(
        restartDelay: const Duration(milliseconds: 240),
      );
      return;
    }

    _onError?.call('Voice recognition stopped. Please try again.');
  }

  Future<bool> _ensureNativePermission() async {
    try {
      var granted = await _nativeSpeech.hasPermission;
      if (!granted) {
        // Re-run initialize once; on iOS this surfaces the native microphone +
        // speech-recognition permission sheet when permission is undecided.
        _nativeInitialized = await _nativeSpeech.initialize(
          onStatus: _handleNativeStatus,
          onError: (_) {},
        );
        granted = await _nativeSpeech.hasPermission;
      }
      if (!granted) {
        _nativeInitialized = false;
        _onError?.call(
          'Microphone access is required. Open Settings → Swipess and allow Microphone and Speech Recognition.',
        );
        return false;
      }
      return _nativeSpeech.isAvailable;
    } catch (_) {
      _nativeInitialized = false;
      return false;
    }
  }

  Future<String> _resolveLocale(String preferred) async {
    try {
      final locales = await _nativeSpeech.locales();
      if (locales.isEmpty) return preferred;

      if (preferred.trim().isEmpty ||
          preferred == 'auto' ||
          preferred == 'en-US' ||
          preferred == 'en') {
        return 'en-US';
      }

      final exact = locales.where((l) => l.localeId == preferred);
      if (exact.isNotEmpty) return exact.first.localeId;

      final language = preferred.split('-').first.toLowerCase();
      final languageMatch = locales.where(
        (l) => l.localeId.toLowerCase().startsWith('$language-'),
      );
      if (languageMatch.isNotEmpty) return languageMatch.first.localeId;

      final system = await _nativeSpeech.systemLocale();
      return system?.localeId ?? locales.first.localeId;
    } catch (_) {
      return preferred;
    }
  }

  void _handleNativeResult(SpeechRecognitionResult result) {
    if (!_active || _intentionalStop || _usingBrowser) return;

    final speech = result.recognizedWords.trim();
    if (speech.isEmpty) return;

    _nativeSessionText = speech;
    _segmentHasSpeech = true;
    _nativeTransientFailures = 0;
    _silenceDeliveredForSegment = false;

    final total = _join(_committed, speech);
    final hasNewTranscript = total != _lastPublished;
    if (hasNewTranscript) {
      // Native recognizers may replay the frozen phrase after a restart. Do not
      // report that replay as resumed speech: only genuinely new text should
      // cancel 3 -> 2 -> 1. Sustained mic energy is handled by the caller.
      _onSpeechActivity?.call();
      _lastPublished = total;
      _onText?.call(total);
    }

    // Start our own silence clock while the native recognizer remains hot.
    // This avoids depending on an OS "done" event to decide the user paused.
    _armNativeSilence();

    // Android/iOS can emit more than one final chunk before the recognizer
    // reports a stopped segment. Commit the final text but keep listening.
    if (result.finalResult) {
      _commitNativeSegment();
    }
  }

  stt.SpeechListenOptions _nativeListenOptions(String localeId) {
    return stt.SpeechListenOptions(
      partialResults: true,
      cancelOnError: false,
      autoPunctuation: true,
      listenMode: _nativeListenMode,
      // Keep the native recognizer alive much longer than the UI silence clock.
      // The UI starts 3 -> 2 -> 1 after ~2.2 s, but the recognizer stays ready
      // so speaking again can continue the same sentence immediately.
      pauseFor: _nativeKeepAlivePause,
      listenFor: const Duration(minutes: 5),
      localeId: localeId,
      onDevice: false,
    );
  }

  Future<void> _attachNativeListen(String localeId) async {
    await _nativeSpeech.listen(
      onResult: _handleNativeResult,
      onSoundLevelChange: (level) {
        if (!_active || _intentionalStop) return;
        _publishSoundLevel(level);
      },
      listenOptions: _nativeListenOptions(localeId),
    );
  }

  Future<void> _startNativeListen() async {
    if (!_active || _intentionalStop || _usingBrowser) return;

    if (_nativeSpeech.isListening) {
      try {
        await _nativeSpeech.stop();
      } catch (_) {}
    }

    _nativeSessionText = '';
    _segmentHasSpeech = false;
    _silenceDeliveredForSegment = false;

    final localeId = await _resolveLocale(_languageCode);
    await _attachNativeListen(localeId);

    if (!_active || _intentionalStop) return;

    if (!_nativeSpeech.isListening) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (!_active || _intentionalStop) return;
      if (!_nativeSpeech.isListening) {
        await _attachNativeListen(localeId);
      }
    }

    if (_nativeSpeech.isListening) {
      _nativeTransientFailures = 0;
      _publishListening(true);
      return;
    }

    if (_nativeTransientFailures < 8) {
      _nativeTransientFailures += 1;
      _finishNativeSegmentAndRestart(
        restartDelay: const Duration(milliseconds: 240),
      );
      return;
    }

    _onError?.call('Could not start listening. Tap the microphone again.');
    _clearSession(keepOwner: false);
  }

  stt.ListenMode get _nativeListenMode {
    switch (_listenMode) {
      case ListenMode.search:
        return stt.ListenMode.search;
      case ListenMode.confirmation:
        return stt.ListenMode.confirmation;
      case ListenMode.dictation:
        return stt.ListenMode.dictation;
    }
  }

  void _handleNativeStatus(String status) {
    if (!_active || _intentionalStop || _usingBrowser) return;
    final normalized = status.toLowerCase();
    if (normalized == stt.SpeechToText.listeningStatus.toLowerCase()) {
      _nativeTransientFailures = 0;
      _publishListening(true);
      return;
    }
    if (normalized == stt.SpeechToText.doneStatus.toLowerCase() ||
        normalized == stt.SpeechToText.notListeningStatus.toLowerCase()) {
      _finishNativeSegmentAndRestart();
    }
  }

  void _flushTranscriptToClient() {
    final pending = _nativeSessionText.trim();
    if (pending.isNotEmpty) {
      _committed = _join(_committed, pending);
      _nativeSessionText = '';
    }
    final total = _normalizeTranscript(_committed);
    if (total.isEmpty) return;
    _committed = total;
    if (total != _lastPublished) {
      _lastPublished = total;
      _onText?.call(total);
    }
  }

  void _deliverSilence() {
    if (!_active || _intentionalStop || _silenceDeliveredForSegment) return;
    _flushTranscriptToClient();
    if (!_segmentHasSpeech) return;
    _silenceDeliveredForSegment = true;
    _browserSilenceTimer?.cancel();
    _browserSilenceTimer = null;
    _nativeSilenceTimer?.cancel();
    _nativeSilenceTimer = null;
    _onSilence?.call();
  }

  void _armNativeSilence() {
    _nativeSilenceTimer?.cancel();
    if (!_active || _intentionalStop || _usingBrowser) return;
    _nativeSilenceTimer = Timer(silenceBeforeCountdown, () {
      _nativeSilenceTimer = null;
      if (!_active || _intentionalStop || _usingBrowser) return;
      _deliverSilence();
    });
  }

  void _finishNativeSegmentAndRestart({
    Duration restartDelay = _nativeRestartDelay,
  }) {
    if (!_active || _intentionalStop || _usingBrowser) return;
    _flushTranscriptToClient();
    _publishSoundLevel(0);

    // Do not equate a native segment ending with "the user is done". Keep the
    // existing silence timer alive so the countdown is based on real elapsed
    // silence, not on Apple/Android recognizer lifecycle noise.
    if (_segmentHasSpeech &&
        !_silenceDeliveredForSegment &&
        _nativeSilenceTimer == null) {
      _armNativeSilence();
    }

    if (!_restartAfterSilence) {
      _nativeRestartTimer?.cancel();
      _nativeRestartTimer = null;
      _nativeRestarting = false;
      _publishListening(false);
      return;
    }

    if (_nativeRestarting) return;
    _nativeRestarting = true;
    _nativeRestartTimer?.cancel();
    _nativeRestartTimer = Timer(restartDelay, () async {
      _nativeRestarting = false;
      if (!_active || _intentionalStop || _usingBrowser) return;
      try {
        await _startNativeListen();
      } catch (_) {
        if (!_active || _intentionalStop) return;
        if (_nativeTransientFailures < 8) {
          _nativeTransientFailures += 1;
          _finishNativeSegmentAndRestart(
            restartDelay: const Duration(milliseconds: 260),
          );
          return;
        }
        _onError?.call(
          'Voice recognition could not restart. Tap the microphone to try again.',
        );
      }
    });
  }

  void _commitNativeSegment() {
    final clean = _nativeSessionText.trim();
    if (clean.isEmpty) return;
    final total = _join(_committed, clean);
    _committed = total;
    _lastPublished = total;
    _nativeSessionText = '';
  }

  void _armBrowserSilence() {
    _browserSilenceTimer?.cancel();
    if (!_active || _intentionalStop || !_usingBrowser) return;
    _browserSilenceTimer = Timer(_effectiveSilenceBeforeCountdown, () {
      _browserSilenceTimer = null;
      if (!_active || _intentionalStop || !_usingBrowser) return;
      _deliverSilence();
    });
  }

  Future<void> cancel({Object? owner}) async {
    if (owner != null && !identical(_owner, owner)) return;
    if (!_active && _owner == null) return;

    _intentionalStop = true;
    _active = false;
    _browserSilenceTimer?.cancel();
    _nativeSilenceTimer?.cancel();
    _nativeRestartTimer?.cancel();
    _browserSilenceTimer = null;
    _nativeSilenceTimer = null;
    _nativeRestartTimer = null;
    _publishSoundLevel(0);

    try {
      if (_usingBrowser) {
        await _browser.cancel();
      } else if (_nativeInitialized) {
        await _nativeSpeech.cancel();
      }
    } catch (_) {}

    _publishListening(false);
    _clearSession(keepOwner: false);
  }

  Future<void> finish({required Object owner}) async {
    if (!identical(_owner, owner)) return;
    if (!_active) return;

    _intentionalStop = true;
    _browserSilenceTimer?.cancel();
    _nativeSilenceTimer?.cancel();
    _nativeRestartTimer?.cancel();
    _browserSilenceTimer = null;
    _nativeSilenceTimer = null;
    _nativeRestartTimer = null;

    try {
      if (_usingBrowser) {
        await _browser.stop();
      } else if (_nativeInitialized) {
        await _nativeSpeech.stop();
        _commitNativeSegment();
      }
    } catch (_) {}

    _active = false;
    _publishSoundLevel(0);
    _publishListening(false);
    _clearSession(keepOwner: false);
  }

  void _clearSession({required bool keepOwner}) {
    _browserSilenceTimer?.cancel();
    _nativeSilenceTimer?.cancel();
    _nativeRestartTimer?.cancel();
    _browserSilenceTimer = null;
    _nativeSilenceTimer = null;
    _nativeRestartTimer = null;
    _active = false;
    _starting = false;
    _intentionalStop = false;
    _usingBrowser = false;
    _nativeRestarting = false;
    _restartAfterSilence = true;
    _segmentHasSpeech = false;
    _silenceDeliveredForSegment = false;
    _nativeSessionText = '';
    if (!keepOwner) _owner = null;
    _lastPublished = '';
    _committed = '';
    _onText = null;
    _onSoundLevel = null;
    _onListeningChanged = null;
    _onSilence = null;
    _onSpeechActivity = null;
    _onError = null;
    _resetPublishedVoiceState();
  }

  /// Merge recognizer output without echoing cumulative or overlapping
  /// callbacks. Native iOS and browser engines may resend the current phrase,
  /// repeat the final phrase, or start the next segment with the last word.
  static String _join(String a, String b) {
    final left = _normalizeTranscript(a);
    final right = _normalizeTranscript(b);
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;

    final leftWords = left.split(' ');
    final rightWords = right.split(' ');
    final leftKey = leftWords.map(_wordKey).join(' ');
    final rightKey = rightWords.map(_wordKey).join(' ');

    if (leftKey == rightKey) return left;
    if (rightKey.startsWith('$leftKey ')) return right;
    if (leftKey.startsWith('$rightKey ')) return left;

    final maxOverlap = leftWords.length < rightWords.length
        ? leftWords.length
        : rightWords.length;
    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final leftTail = leftWords
          .sublist(leftWords.length - overlap)
          .map(_wordKey)
          .join(' ');
      final rightHead = rightWords.take(overlap).map(_wordKey).join(' ');
      if (leftTail == rightHead) {
        return _normalizeTranscript(
          '$left ${rightWords.skip(overlap).join(' ')}',
        );
      }
    }
    return _normalizeTranscript('$left $right');
  }

  static String _normalizeTranscript(String input) {
    final clean = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return clean;

    final words = clean.split(' ');
    final output = <String>[];
    for (final word in words) {
      if (output.isNotEmpty && _wordKey(output.last) == _wordKey(word)) {
        continue;
      }
      output.add(word);
    }

    // Some recognizers repeat a whole short phrase at a segment boundary:
    // "find people find people". Remove only an exact repeated prefix/suffix,
    // leaving intentional non-adjacent repetition intact.
    for (var size = output.length ~/ 2; size >= 2; size--) {
      final start = output.length - (size * 2);
      if (start < 0) continue;
      final first = output.sublist(start, start + size).map(_wordKey).join(' ');
      final second = output.sublist(start + size).map(_wordKey).join(' ');
      if (first == second) {
        output.removeRange(start + size, output.length);
        break;
      }
    }
    return output.join(' ');
  }

  static String _wordKey(String word) {
    return word.toLowerCase().replaceAll(
      RegExp(r"[^\p{L}\p{N}']", unicode: true),
      '',
    );
  }
}
