from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing expected snippet: {label}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Shared speech coordinator: 3.5 seconds silence before each surface begins
# its visible 3 -> 2 -> 1 auto-send countdown.
# ---------------------------------------------------------------------------
p = Path("lib/src/features/ai/presentation/services/live_voice_input.dart")
s = p.read_text()
s = replace_once(
    s,
    "/// After roughly four seconds of silence callers receive [onSilence] and can\n",
    "/// After 3.5 seconds of silence callers receive [onSilence] and can\n",
    "shared voice documentation",
)
s = replace_once(
    s,
    "  static const silenceBeforeCountdown = Duration(seconds: 4);",
    "  static const silenceBeforeCountdown = Duration(milliseconds: 3500);",
    "shared silence duration",
)
p.write_text(s)


# ---------------------------------------------------------------------------
# Dashboard blue field: replace the record -> server transcription path with
# the same live speech coordinator already used successfully by Intel Core.
# ---------------------------------------------------------------------------
p = Path("lib/src/core/widgets/glow_search_bar.dart")
s = p.read_text()
s = replace_once(
    s,
    "import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';\n",
    "import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';\n",
    "dashboard voice import",
)
s = s.replace("import 'package:record/record.dart';\n", "")
s = replace_once(
    s,
    "/// Native voice uses the same record -> server transcription pipeline used by\n"
    "/// the reliable voice-note flow instead of depending on iOS SpeechRecognizer\n"
    "/// staying alive while Flutter focus/keyboard state changes. The microphone is\n"
    "/// deliberately started with the keyboard unfocused; tapping it again stops,\n"
    "/// transcribes and submits the recognized text through the normal AI search.\n",
    "/// Dashboard voice uses the same live speech coordinator as Intel Core. Words\n"
    "/// appear while the user speaks; 3.5 seconds of silence starts a visible\n"
    "/// 3 -> 2 -> 1 countdown, then the request submits automatically. Speaking\n"
    "/// again during the countdown cancels it and continues the same dictation.\n",
    "dashboard voice docs",
)
s = replace_once(
    s,
    "  late final VoiceTranscribeRepository _voiceRepo;\n"
    "  late final DeckAudioNotifier _audioNotifier;\n"
    "  StreamSubscription<Amplitude>? _amplitudeSub;\n",
    "  final _voice = LiveVoiceInput.instance;\n"
    "  late final DeckAudioNotifier _audioNotifier;\n"
    "  Timer? _countdownTimer;\n"
    "  int? _countdown;\n",
    "dashboard voice fields",
)
s = replace_once(
    s,
    "    _voiceRepo = ref.read(voiceTranscribeRepositoryProvider);\n",
    "",
    "dashboard old repo init",
)
s = replace_once(
    s,
    "    _amplitudeSub?.cancel();\n"
    "    unawaited(_voiceRepo.cancel());\n",
    "    _countdownTimer?.cancel();\n"
    "    unawaited(_voice.cancel(owner: this));\n",
    "dashboard dispose",
)

new_dashboard_voice = r'''  void _cancelVoiceCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  void _beginVoiceCountdown() {
    if (!mounted ||
        !_voiceActive ||
        (widget.controller?.text.trim().isEmpty ?? true) ||
        _inlineAiLoading) {
      return;
    }
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _countdown ?? 0;
      if (current > 1) {
        setState(() => _countdown = current - 1);
        return;
      }
      timer.cancel();
      _countdownTimer = null;
      setState(() => _countdown = null);
      unawaited(_finishVoiceAndSubmit());
    });
  }

  Future<void> _finishVoiceAndSubmit() async {
    _cancelVoiceCountdown();
    if (_voice.isOwnedBy(this)) {
      await _voice.finish(owner: this);
    }
    if (!mounted) {
      _restoreVoiceAudio();
      return;
    }
    setState(() {
      _voiceActive = false;
      _transcribing = false;
      _voiceLevel = 0;
    });
    _restoreVoiceAudio();
    final text = widget.controller?.text.trim() ?? '';
    if (text.isNotEmpty) _submitSearch(text);
  }

  Future<void> _toggleVoice() async {
    if (!_isEditableSearch) {
      widget.onTap?.call();
      return;
    }
    if (_inlineAiLoading || _transcribing) return;

    if (_voice.isOwnedBy(this) || _voiceActive) {
      await _finishVoiceAndSubmit();
      return;
    }

    AppHaptics.light();
    FocusManager.instance.primaryFocus?.unfocus();
    _suppressVoiceAudio();

    try {
      final started = await _voice.start(
        owner: this,
        initialText: widget.controller?.text ?? '',
        languageCode: ref.read(voiceLanguageProvider).localeCode,
        listenMode: ListenMode.search,
        onText: (text) {
          if (!mounted) return;
          _cancelVoiceCountdown();
          final controller = widget.controller;
          if (controller != null) {
            controller.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
            widget.onChanged?.call(text);
          }
          if (!_voiceActive) setState(() => _voiceActive = true);
        },
        onSilence: _beginVoiceCountdown,
        onListeningChanged: (listening) {
          if (!mounted) return;
          final active = _voice.isOwnedBy(this);
          if (_voiceActive != active || (!listening && _voiceLevel != 0)) {
            setState(() {
              _voiceActive = active;
              if (!listening) _voiceLevel = 0;
            });
          }
        },
        onSoundLevel: (level) {
          if (!mounted) return;
          final normalized = level <= 0
              ? ((level + 45) / 45).clamp(0.0, 1.0).toDouble()
              : (level / 10).clamp(0.0, 1.0).toDouble();
          if ((_voiceLevel - normalized).abs() > .01) {
            setState(() => _voiceLevel = normalized);
          }
        },
        onError: _showVoiceError,
      );

      if (!mounted) return;
      setState(() {
        _voiceActive = started;
        _voiceLevel = 0;
      });
      if (!started) _restoreVoiceAudio();
    } catch (_) {
      _restoreVoiceAudio();
      _showVoiceError('Could not start voice search. Please try again.');
    }
  }

  void _submitSearch(String raw) {'''
pattern = re.compile(
    r"  Future<void> _toggleVoice\(\) async \{.*?\n  void _submitSearch\(String raw\) \{",
    re.S,
)
s, count = pattern.subn(new_dashboard_voice, s, count=1)
if count != 1:
    raise SystemExit("Could not replace dashboard voice implementation")

s = replace_once(
    s,
    "  void _submitSearch(String raw) {\n    final input = raw.trim();",
    "  void _submitSearch(String raw) {\n"
    "    if (_voice.isOwnedBy(this) || _voiceActive) {\n"
    "      unawaited(_finishVoiceAndSubmit());\n"
    "      return;\n"
    "    }\n"
    "    _cancelVoiceCountdown();\n"
    "    final input = raw.trim();",
    "dashboard submit finalizes voice",
)
s = replace_once(
    s,
    "      !_voiceActive &&\n      !_transcribing &&\n      !_inlineAiLoading;",
    "      !_voiceActive &&\n      !_transcribing &&\n      _countdown == null &&\n      !_inlineAiLoading;",
    "dashboard prompt/countdown visibility",
)
s = replace_once(
    s,
    "      label: _transcribing\n"
    "          ? 'Transcribing voice search'\n"
    "          : _voiceActive\n"
    "              ? 'Stop and transcribe voice search'\n"
    "              : 'Start voice search',",
    "      label: _countdown != null\n"
    "          ? 'Voice search sends in $_countdown'\n"
    "          : _voiceActive\n"
    "              ? 'Finish voice search now'\n"
    "              : 'Start voice search',",
    "dashboard mic semantics",
)
s = replace_once(
    s,
    "        onTap: _transcribing ? null : _toggleVoice,",
    "        onTap: _toggleVoice,",
    "dashboard mic action",
)
s = replace_once(
    s,
    "    final voiceVisible = _voiceActive || _transcribing;",
    "    final voiceVisible = _voiceActive || _transcribing || _countdown != null;",
    "dashboard voice visibility",
)
s = replace_once(
    s,
    "                          hintText: _voiceActive &&\n"
    "                                  (widget.controller?.text.trim().isEmpty ?? true)\n"
    "                              ? 'Listening…'\n"
    "                              : _transcribing\n"
    "                                  ? 'Transcribing…'\n"
    "                                  : null,",
    "                          hintText: _countdown != null\n"
    "                              ? 'Sending in $_countdown…'\n"
    "                              : _voiceActive &&\n"
    "                                      (widget.controller?.text.trim().isEmpty ?? true)\n"
    "                                  ? 'Listening…'\n"
    "                                  : null,",
    "dashboard voice hint",
)
s = replace_once(
    s,
    "                  onPressed: _transcribing\n"
    "                      ? null\n"
    "                      : () => _submitSearch(widget.controller?.text ?? ''),",
    "                  onPressed: () =>\n"
    "                      _submitSearch(widget.controller?.text ?? ''),",
    "dashboard send action",
)
s = replace_once(
    s,
    "                _transcribing\n"
    "                    ? 'Transcribing your voice…'\n"
    "                    : 'Listening… tap the microphone when you finish',",
    "                _countdown != null\n"
    "                    ? 'Silence detected · sending in $_countdown…'\n"
    "                    : 'Listening… speak naturally',",
    "dashboard status text",
)
p.write_text(s)


# ---------------------------------------------------------------------------
# Person-to-person chat: same live dictation and silence/countdown auto-send.
# ---------------------------------------------------------------------------
p = Path("lib/src/features/messages/presentation/screens/chat_screen.dart")
s = p.read_text()
s = replace_once(
    s,
    "import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';\n",
    "import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';\n",
    "chat voice import",
)
s = replace_once(
    s,
    "  final _controller = TextEditingController();\n"
    "  final _scroll = ScrollController();\n"
    "  final _search = TextEditingController();\n",
    "  final _controller = TextEditingController();\n"
    "  final _scroll = ScrollController();\n"
    "  final _search = TextEditingController();\n"
    "  final _voice = LiveVoiceInput.instance;\n",
    "chat voice field",
)
s = replace_once(
    s,
    "  bool _recording = false;\n  bool _transcribing = false;\n",
    "  bool _recording = false;\n"
    "  bool _transcribing = false;\n"
    "  int? _countdown;\n"
    "  Timer? _countdownTimer;\n",
    "chat countdown state",
)
s = replace_once(
    s,
    "    unawaited(ref.read(voiceTranscribeRepositoryProvider).cancel());\n",
    "    _countdownTimer?.cancel();\n"
    "    unawaited(_voice.cancel(owner: this));\n",
    "chat dispose voice",
)

new_chat_voice = r'''  void _cancelVoiceCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  void _beginVoiceCountdown() {
    if (!mounted || !_recording || _controller.text.trim().isEmpty || _sending) {
      return;
    }
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _countdown ?? 0;
      if (current > 1) {
        setState(() => _countdown = current - 1);
        return;
      }
      timer.cancel();
      _countdownTimer = null;
      setState(() => _countdown = null);
      unawaited(_finishVoiceAndSend());
    });
  }

  Future<void> _finishVoiceAndSend() async {
    _cancelVoiceCountdown();
    if (_voice.isOwnedBy(this)) {
      await _voice.finish(owner: this);
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _transcribing = false;
    });
    if (_controller.text.trim().isNotEmpty) await _send();
  }

  Future<void> _toggleVoice() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_voice.isOwnedBy(this) || _recording) {
      await _finishVoiceAndSend();
      return;
    }

    AppHaptics.light();
    try {
      final lang = ref.read(appLocaleProvider).isEs ? 'es-MX' : 'en-US';
      final started = await _voice.start(
        owner: this,
        initialText: _controller.text,
        languageCode: lang,
        listenMode: ListenMode.dictation,
        onText: (text) {
          if (!mounted) return;
          _cancelVoiceCountdown();
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          if (!_recording) setState(() => _recording = true);
        },
        onSilence: _beginVoiceCountdown,
        onListeningChanged: (_) {
          if (!mounted) return;
          final active = _voice.isOwnedBy(this);
          if (_recording != active) setState(() => _recording = active);
        },
        onError: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      );
      if (mounted) setState(() => _recording = started);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the microphone')),
        );
      }
    }
  }

  Future<void> _send([String? preset]) async {'''
pattern = re.compile(
    r"  Future<void> _toggleVoice\(\) async \{.*?\n  Future<void> _send\(\[String\? preset\]\) async \{",
    re.S,
)
s, count = pattern.subn(new_chat_voice, s, count=1)
if count != 1:
    raise SystemExit("Could not replace chat voice implementation")

s = replace_once(
    s,
    "  Future<void> _send([String? preset]) async {\n"
    "    final text = (preset ?? _controller.text).trim();",
    "  Future<void> _send([String? preset]) async {\n"
    "    if (preset == null && (_voice.isOwnedBy(this) || _recording)) {\n"
    "      _cancelVoiceCountdown();\n"
    "      await _voice.finish(owner: this);\n"
    "      if (mounted) setState(() => _recording = false);\n"
    "    }\n"
    "    final text = (preset ?? _controller.text).trim();",
    "chat manual send finalizes voice",
)
s = replace_once(
    s,
    "                  transcribing: _transcribing,\n                  sending: _sending,",
    "                  transcribing: _transcribing,\n"
    "                  countdown: _countdown,\n"
    "                  sending: _sending,",
    "chat composer countdown argument",
)
s = replace_once(
    s,
    "                  onVoice: _transcribing ? null : _toggleVoice,",
    "                  onVoice: _toggleVoice,",
    "chat composer mic action",
)
s = replace_once(
    s,
    "    required this.transcribing,\n    required this.sending,",
    "    required this.transcribing,\n"
    "    required this.countdown,\n"
    "    required this.sending,",
    "chat composer constructor countdown",
)
s = replace_once(
    s,
    "  final bool transcribing;\n  final bool sending;",
    "  final bool transcribing;\n"
    "  final int? countdown;\n"
    "  final bool sending;",
    "chat composer countdown field",
)
s = replace_once(
    s,
    "            if (recording || transcribing)\n",
    "            if (recording || transcribing || countdown != null)\n",
    "chat voice status visibility",
)
s = replace_once(
    s,
    "                      recording ? 'LISTENING · TAP MIC TO FINISH' : 'TRANSCRIBING…',",
    "                      countdown != null\n"
    "                          ? 'SILENCE · SENDING IN $countdown…'\n"
    "                          : recording\n"
    "                              ? 'LISTENING · SPEAK NATURALLY'\n"
    "                              : 'TRANSCRIBING…',",
    "chat voice status text",
)
s = replace_once(
    s,
    "                    tooltip: transcribing ? 'Transcribing' : 'Voice message',\n"
    "                    active: recording || transcribing,",
    "                    tooltip: countdown != null\n"
    "                        ? 'Sending in $countdown'\n"
    "                        : recording\n"
    "                            ? 'Finish voice message now'\n"
    "                            : 'Voice message',\n"
    "                    active: recording || transcribing || countdown != null,",
    "chat mic state",
)
p.write_text(s)
