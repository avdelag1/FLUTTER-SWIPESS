from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing expected block: {label}")
    return text.replace(old, new, 1)


# Dashboard voice: use the shared live speech recognizer instead of waiting for
# a post-recording transcription. This renders partial words while speaking and
# uses the recognizer's silence callback for the visible 3 -> 2 -> 1 auto-send.
path = Path("lib/src/core/widgets/glow_search_bar.dart")
s = path.read_text()
s = replace_once(
    s,
    "import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';\n",
    "import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';\n",
    "live voice import",
)
s = s.replace("import 'package:record/record.dart';\n", "")
s = s.replace("  static const _silenceBeforeCountdown = Duration(milliseconds: 3200);\n\n", "", 1)
s = replace_once(
    s,
    "  late final VoiceTranscribeRepository _voiceRecorder;\n"
    "  late final DeckAudioNotifier _audioNotifier;\n"
    "  StreamSubscription<Amplitude>? _voiceAmplitudeSub;\n"
    "  Timer? _voiceSilenceTimer;\n"
    "  Timer? _countdownTimer;\n"
    "  int? _countdown;\n"
    "  bool _voiceHasSpeech = false;\n"
    "  String _voiceInitialText = '';\n",
    "  final LiveVoiceInput _voice = LiveVoiceInput.instance;\n"
    "  late final DeckAudioNotifier _audioNotifier;\n"
    "  Timer? _countdownTimer;\n"
    "  int? _countdown;\n"
    "  bool _voiceHasSpeech = false;\n",
    "voice state",
)
s = s.replace("    _voiceRecorder = ref.read(voiceTranscribeRepositoryProvider);\n", "", 1)
s = replace_once(
    s,
    "    _voiceSilenceTimer?.cancel();\n"
    "    unawaited(_voiceAmplitudeSub?.cancel());\n"
    "    unawaited(_voiceRecorder.cancel());\n",
    "    unawaited(_voice.cancel(owner: this));\n",
    "voice dispose",
)

voice_block = r'''  void _beginVoiceCountdown() {
    if (!mounted ||
        !_voice.isOwnedBy(this) ||
        !_voice.active ||
        !_voiceHasSpeech ||
        _inlineAiLoading) {
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

  Future<void> _finishVoiceAndSubmit() async {
    _cancelVoiceCountdown();
    if (!_voiceActive && !_voice.isOwnedBy(this)) return;

    final beforeFinish = widget.controller?.text.trim() ?? '';
    if (mounted) {
      setState(() {
        _voiceActive = false;
        _transcribing = true;
        _voiceLevel = 0;
      });
    }

    try {
      await _voice.finish(owner: this);
    } catch (_) {}

    if (!mounted) {
      _restoreVoiceAudio();
      return;
    }

    final current = widget.controller?.text.trim() ?? '';
    final text = current.isNotEmpty ? current : beforeFinish;
    setState(() {
      _transcribing = false;
      _voiceActive = false;
      _voiceLevel = 0;
      _voiceHasSpeech = false;
    });
    _restoreVoiceAudio();

    if (text.isEmpty) {
      _showVoiceError('I did not catch that. Please try speaking again.');
      return;
    }
    _submitSearch(text);
  }

  Future<void> _toggleVoice() async {
    if (!_isEditableSearch) {
      widget.onTap?.call();
      return;
    }
    if (_inlineAiLoading || _transcribing) return;

    if (_voiceActive || _voice.isOwnedBy(this)) {
      await _finishVoiceAndSubmit();
      return;
    }

    unawaited(AppHaptics.voiceStart());
    FocusManager.instance.primaryFocus?.unfocus();
    _suppressVoiceAudio();
    _voiceHasSpeech = false;
    _cancelVoiceCountdown();
    setState(() {
      _transcribing = true;
      _voiceLevel = 0;
    });

    final controller = widget.controller;
    final started = await _voice.start(
      languageCode: ref.read(voiceLanguageProvider).localeCode,
      owner: this,
      initialText: controller?.text.trim() ?? '',
      onText: (text) {
        if (!mounted) return;
        _voiceHasSpeech = text.trim().isNotEmpty;
        _cancelVoiceCountdown();
        if (controller != null) {
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          widget.onChanged?.call(text);
        }
        if (!_voiceActive || _transcribing) {
          setState(() {
            _voiceActive = true;
            _transcribing = false;
          });
        }
      },
      onSilence: _beginVoiceCountdown,
      onListeningChanged: (listening) {
        if (!mounted) return;
        if (listening) {
          if (!_voiceActive || _transcribing) {
            setState(() {
              _voiceActive = true;
              _transcribing = false;
            });
          }
          return;
        }
        if (_voice.isOwnedBy(this) && _voice.active) return;
        setState(() {
          _voiceActive = false;
          _transcribing = false;
          _voiceLevel = 0;
        });
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
      onError: (message) {
        if (!mounted) return;
        _cancelVoiceCountdown();
        unawaited(_voice.cancel(owner: this));
        setState(() {
          _voiceActive = false;
          _transcribing = false;
          _voiceLevel = 0;
          _voiceHasSpeech = false;
        });
        _restoreVoiceAudio();
        _showVoiceError(message);
      },
    );

    if (!mounted) return;
    setState(() {
      _transcribing = false;
      _voiceActive = started && _voice.isOwnedBy(this) && _voice.active;
      if (!_voiceActive) _voiceLevel = 0;
    });
    if (!started) _restoreVoiceAudio();
  }
'''

s, count = re.subn(
    r"  void _beginVoiceCountdown\(\) \{.*?\n  void _submitSearch",
    voice_block + "\n  void _submitSearch",
    s,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit("voice function block not found")

# Generic questions must never accidentally surface directory cards. Contacts
# are rendered only when the user's own query is classified as a contact query.
s = s.replace(
    "                    'CONTACT REQUESTS: when the user wants a person, worker, or '\n"
    "                    'business contact, return trusted Local Brain matches with '\n"
    "                    'their contact cards. Never send them to Seekers or another '\n"
    "                    'page for contacts — cards render inline on the dashboard.\\n\\n'\n",
    "                    'CONTACT REQUESTS: only when the user explicitly asks for a person, worker, '\n"
    "                    'business, recommendation, or contact, return trusted Local Brain matches. '\n"
    "                    'For ordinary conversation, questions, greetings, or checks like are you there, '\n"
    "                    'never return Local Brain/profile/contact cards. Keep the answer on Dashboard.\\n\\n'\n",
    1,
)
s = replace_once(
    s,
    "        _inlineLocalBrain = parsed.localBrain;\n",
    "        _inlineLocalBrain = contactQuery ? parsed.localBrain : const [];\n",
    "generic query contact suppression",
)
path.write_text(s)

# Smaller AUTO selector.
path = Path("lib/src/features/ai/presentation/widgets/voice_language_selector.dart")
s = path.read_text()
s = s.replace("borderRadius: BorderRadius.circular(16)", "borderRadius: BorderRadius.circular(12)")
s = s.replace("            height: 36,", "            height: 28,", 1)
s = s.replace("            padding: const EdgeInsets.symmetric(horizontal: 12),", "            padding: const EdgeInsets.symmetric(horizontal: 8),", 1)
s = s.replace("                fontSize: 13,", "                fontSize: 10.5,", 1)
path.write_text(s)

# Faster dashboard/event/page transitions.
path = Path("lib/src/features/dashboard/presentation/screens/dashboard_shell.dart")
s = path.read_text()
s = s.replace(
    "Duration(milliseconds: persistentChromeVisible ? 360 : 500)",
    "Duration(milliseconds: persistentChromeVisible ? 140 : 170)",
    1,
)
s = s.replace(": const Duration(milliseconds: 220);", ": const Duration(milliseconds: 120);", 1)
s = s.replace("duration: const Duration(milliseconds: 420),", "duration: const Duration(milliseconds: 110),", 1)
path.write_text(s)

path = Path("lib/src/features/swipes/presentation/utils/open_swipe_deck.dart")
s = path.read_text()
s = s.replace("transitionDuration: const Duration(milliseconds: 90),", "transitionDuration: Duration.zero,", 1)
s = s.replace("reverseTransitionDuration: const Duration(milliseconds: 110),", "reverseTransitionDuration: const Duration(milliseconds: 80),", 1)
path.write_text(s)

# Dark backing canvas removes the white first frame while the map renderer boots.
path = Path("lib/src/features/map/presentation/screens/platform_discovery_map_screen.dart")
s = path.read_text()
needle = "          children: [\n            buildPlatformDiscoveryMap(\n"
if "const ColoredBox(color: Color(0xFF06182B))," not in s:
    s = replace_once(
        s,
        needle,
        "          children: [\n            const ColoredBox(color: Color(0xFF06182B)),\n            buildPlatformDiscoveryMap(\n",
        "dark map backing",
    )
path.write_text(s)
