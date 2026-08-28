from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match in {path}, found {count}")
    p.write_text(text.replace(old, new, 1))
    print(f"patched: {label}")


def replace_between(path: str, start: str, end: str, replacement: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f"{label}: start marker missing in {path}")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f"{label}: end marker missing in {path}")
    p.write_text(text[:start_index] + replacement + text[end_index:])
    print(f"patched: {label}")


# Dashboard voice: use recorder + server Whisper as final authority. The audio
# amplitude stream keeps the existing instant waveform and 3-2-1 silence UX.
path = "lib/src/core/widgets/glow_search_bar.dart"
replace_once(
    path,
    "import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';\nimport 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';\n",
    "import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';\nimport 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';\n",
    "dashboard voice repository import",
)
replace_once(
    path,
    "import 'package:google_fonts/google_fonts.dart';\n",
    "import 'package:google_fonts/google_fonts.dart';\nimport 'package:record/record.dart';\n",
    "dashboard amplitude import",
)
replace_once(
    path,
    "/// Dashboard voice uses the same live speech coordinator as Intel Core. Words\n/// appear while the user speaks; 3.5 seconds of silence starts a visible\n/// 3 -> 2 -> 1 countdown, then the request submits automatically. Speaking\n/// again during the countdown cancels it and continues the same dictation.\n",
    "/// Dashboard voice records the actual microphone audio and sends it to the\n/// high-accuracy Whisper transcription backend. The amplitude stream keeps the\n/// UI reactive while the user speaks; silence starts the existing 3 -> 2 -> 1\n/// countdown, and speaking again cancels the countdown before transcription.\n",
    "dashboard voice documentation",
)
replace_once(
    path,
    "  final _voice = LiveVoiceInput.instance;\n  late final DeckAudioNotifier _audioNotifier;\n  Timer? _countdownTimer;\n  int? _countdown;\n",
    "  late final VoiceTranscribeRepository _voiceRecorder;\n  late final DeckAudioNotifier _audioNotifier;\n  StreamSubscription<Amplitude>? _voiceAmplitudeSub;\n  Timer? _voiceSilenceTimer;\n  Timer? _countdownTimer;\n  int? _countdown;\n  bool _voiceHasSpeech = false;\n  String _voiceInitialText = '';\n",
    "dashboard voice state",
)
replace_once(
    path,
    "    _audioNotifier = ref.read(deckSoundOnProvider.notifier);\n",
    "    _voiceRecorder = ref.read(voiceTranscribeRepositoryProvider);\n    _audioNotifier = ref.read(deckSoundOnProvider.notifier);\n",
    "dashboard voice repository initialization",
)
replace_once(
    path,
    "    _promptTimer?.cancel();\n    _countdownTimer?.cancel();\n    unawaited(_voice.cancel(owner: this));\n    _restoreVoiceAudio();\n",
    "    _promptTimer?.cancel();\n    _countdownTimer?.cancel();\n    _voiceSilenceTimer?.cancel();\n    unawaited(_voiceAmplitudeSub?.cancel());\n    unawaited(_voiceRecorder.cancel());\n    _restoreVoiceAudio();\n",
    "dashboard voice disposal",
)

new_countdown = '''  void _beginVoiceCountdown() {
    if (!mounted || !_voiceActive || !_voiceHasSpeech || _inlineAiLoading) {
      return;
    }
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    unawaited(AppHaptics.countdownTick(3));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _countdown ?? 0;
      if (current > 1) {
        final next = current - 1;
        setState(() => _countdown = next);
        unawaited(AppHaptics.countdownTick(next));
        return;
      }
      timer.cancel();
      _countdownTimer = null;
      setState(() => _countdown = null);
      unawaited(AppHaptics.voiceCommit());
      unawaited(_finishVoiceAndSubmit());
    });
  }

'''
replace_between(
    path,
    "  void _beginVoiceCountdown() {",
    "  Future<void> _finishVoiceAndSubmit() async {",
    new_countdown,
    "dashboard silence countdown",
)

new_finish = '''  Future<void> _finishVoiceAndSubmit() async {
    _cancelVoiceCountdown();
    _voiceSilenceTimer?.cancel();
    _voiceSilenceTimer = null;
    await _voiceAmplitudeSub?.cancel();
    _voiceAmplitudeSub = null;

    if (!_voiceActive) return;
    _voiceActive = false;
    if (mounted) {
      setState(() {
        _transcribing = true;
        _voiceLevel = 0;
      });
    }

    String transcript = '';
    String? voiceError;
    try {
      final language = ref.read(voiceLanguageProvider);
      transcript = await _voiceRecorder.stop(language: language.localeCode);
    } on VoiceTranscribeException catch (error) {
      voiceError = error.message;
    } catch (_) {
      voiceError = 'Could not transcribe that audio. Please try again.';
    }

    if (!mounted) {
      _restoreVoiceAudio();
      return;
    }

    setState(() {
      _transcribing = false;
      _voiceLevel = 0;
      _voiceHasSpeech = false;
    });
    _restoreVoiceAudio();

    if (voiceError != null) {
      _showVoiceError(voiceError);
      return;
    }

    final spoken = transcript.trim();
    if (spoken.isEmpty) {
      _showVoiceError('I did not catch that. Please try speaking again.');
      return;
    }

    final text = [_voiceInitialText.trim(), spoken]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
    _voiceInitialText = '';

    final controller = widget.controller;
    if (controller != null) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      widget.onChanged?.call(text);
    }
    _submitSearch(text);
  }

'''
replace_between(
    path,
    "  Future<void> _finishVoiceAndSubmit() async {",
    "  Future<void> _toggleVoice() async {",
    new_finish,
    "dashboard Whisper finalization",
)

new_toggle = '''  Future<void> _toggleVoice() async {
    if (!_isEditableSearch) {
      widget.onTap?.call();
      return;
    }
    if (_inlineAiLoading || _transcribing) return;

    if (_voiceActive) {
      await _finishVoiceAndSubmit();
      return;
    }

    unawaited(AppHaptics.voiceStart());
    FocusManager.instance.primaryFocus?.unfocus();
    _suppressVoiceAudio();
    _voiceInitialText = widget.controller?.text.trim() ?? '';
    _voiceHasSpeech = false;

    setState(() {
      _transcribing = true;
      _voiceLevel = 0;
    });

    try {
      final started = await _voiceRecorder.start();
      if (!mounted) return;
      if (!started) {
        setState(() {
          _transcribing = false;
          _voiceActive = false;
          _voiceLevel = 0;
        });
        _restoreVoiceAudio();
        _showVoiceError(
          'Voice search could not start. Check microphone permission in Settings.',
        );
        return;
      }

      setState(() {
        _transcribing = false;
        _voiceActive = true;
        _voiceLevel = 0;
      });

      await _voiceAmplitudeSub?.cancel();
      _voiceAmplitudeSub = _voiceRecorder
          .amplitudeStream(interval: const Duration(milliseconds: 80))
          .listen((amplitude) {
            if (!mounted || !_voiceActive) return;
            final raw = amplitude.current;
            final normalized = raw.isFinite
                ? ((raw + 60) / 60).clamp(0.0, 1.0).toDouble()
                : 0.0;
            if ((_voiceLevel - normalized).abs() > .01) {
              setState(() => _voiceLevel = normalized);
            }

            // Typical speech is comfortably above -48 dBFS. Only arm silence
            // after actual voice energy so an open mic never auto-submits noise.
            if (raw.isFinite && raw > -48) {
              _voiceHasSpeech = true;
              _cancelVoiceCountdown();
              _voiceSilenceTimer?.cancel();
              _voiceSilenceTimer = Timer(
                const Duration(milliseconds: 2800),
                _beginVoiceCountdown,
              );
            }
          });
    } catch (_) {
      try {
        await _voiceRecorder.cancel();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _voiceActive = false;
        _voiceLevel = 0;
        _voiceHasSpeech = false;
      });
      _restoreVoiceAudio();
      _showVoiceError('Could not start voice search. Please try again.');
    }
  }

'''
replace_between(
    path,
    "  Future<void> _toggleVoice() async {",
    "  void _submitSearch(String raw) {",
    new_toggle,
    "dashboard high-accuracy recorder flow",
)
replace_once(
    path,
    "    if (_voice.isOwnedBy(this) || _voiceActive) {\n      unawaited(_finishVoiceAndSubmit());\n      return;\n    }\n",
    "    if (_voiceActive) {\n      unawaited(_finishVoiceAndSubmit());\n      return;\n    }\n",
    "dashboard submit while recording",
)

# Shared live voice remains used by Intel Core/chat. AUTO now means the native
# OS locale or navigator.language instead of silently falling back to en-US.
path = "lib/src/features/ai/presentation/services/live_voice_input.dart"
replace_once(
    path,
    "  String _languageCode = 'en-US';\n",
    "  String _languageCode = '';\n",
    "live voice automatic locale default",
)
replace_once(
    path,
    "  void setLanguage(String langCode) {\n    final clean = langCode.trim();\n    if (clean.isNotEmpty) _languageCode = clean;\n    if (kIsWeb) _browser.setLanguage(_languageCode);\n  }\n",
    "  void setLanguage(String langCode) {\n    _languageCode = langCode.trim();\n    if (kIsWeb) _browser.setLanguage(_languageCode);\n  }\n",
    "live voice automatic locale setter",
)
new_locale = '''  Future<String> _resolveLocale(String preferred) async {
    try {
      final locales = await _nativeSpeech.locales();
      if (locales.isEmpty) return preferred;

      if (preferred.trim().isEmpty || preferred == 'auto') {
        final system = await _nativeSpeech.systemLocale();
        if (system != null && system.localeId.trim().isNotEmpty) {
          return system.localeId;
        }
        return locales.first.localeId;
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

'''
replace_between(
    path,
    "  Future<String> _resolveLocale(String preferred) async {",
    "  void _handleNativeResult(SpeechRecognitionResult result) {",
    new_locale,
    "live voice system locale resolution",
)

# Web Speech AUTO must resolve to the browser/OS locale rather than an invalid
# "auto-AUTO" BCP-47 language tag.
path = "web/index.html"
replace_once(
    path,
    "        setLanguage: function(lang) {\n          selectedLang = lang;\n        },\n",
    "        setLanguage: function(lang) {\n          selectedLang = (lang && lang !== 'auto') ? lang : null;\n        },\n",
    "browser speech automatic language",
)

# Remove one-shot CI helpers from the branch's resulting source commit.
for temporary in (
    ".github/workflows/one-shot-dashboard-whisper.yml",
    ".github/patch_dashboard_whisper_accuracy.py",
):
    p = Path(temporary)
    if p.exists():
        p.unlink()
