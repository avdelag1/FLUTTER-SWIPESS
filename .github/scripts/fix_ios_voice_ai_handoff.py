from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    out, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one regex match, got {count}")
    return out


# Shared voice service -------------------------------------------------------
voice_path = Path("lib/src/features/ai/presentation/services/live_voice_input.dart")
voice = voice_path.read_text()

voice = replace_once(
    voice,
    """/// After 3.5 seconds of silence callers receive [onSilence] and can
/// render the existing 3 -> 2 -> 1 auto-send countdown. Native recognition is
/// immediately restarted after silence so speaking again can cancel that
/// countdown and continue the same message.
""",
    """/// After 3.5 seconds of silence callers receive [onSilence] and can
/// render the existing 3 -> 2 -> 1 auto-send countdown. Callers that need a
/// deterministic hands-free send can disable native restart-after-silence so
/// iOS cannot start a second recognition segment underneath the countdown.
""",
    "voice service documentation",
)

voice = replace_once(
    voice,
    """  bool _nativeInitialized = false;
  bool _nativeRestarting = false;
  int _nativeTransientFailures = 0;
""",
    """  bool _nativeInitialized = false;
  bool _nativeRestarting = false;
  bool _restartAfterSilence = true;
  int _nativeTransientFailures = 0;
""",
    "voice restart state",
)

voice = replace_once(
    voice,
    """    ListenMode listenMode = ListenMode.dictation,
    String? languageCode,
  }) async {
""",
    """    ListenMode listenMode = ListenMode.dictation,
    String? languageCode,
    bool restartAfterSilence = true,
  }) async {
""",
    "voice start signature",
)

voice = replace_once(
    voice,
    """    _onError = onError;
    _listenMode = listenMode;
    _committed = initialText.trim();
""",
    """    _onError = onError;
    _listenMode = listenMode;
    _restartAfterSilence = restartAfterSilence;
    _committed = initialText.trim();
""",
    "voice restart option assignment",
)

voice = replace_once(
    voice,
    """    if (_segmentHasSpeech && !_silenceDeliveredForSegment) {
      _silenceDeliveredForSegment = true;
      _onSilence?.call();
    }

    if (_nativeRestarting) return;
""",
    """    if (_segmentHasSpeech && !_silenceDeliveredForSegment) {
      _silenceDeliveredForSegment = true;
      _onSilence?.call();
    }

    // Dashboard and Intel Core use one-shot hands-free voice. Once silence has
    // handed valid text to their visible 3 -> 2 -> 1 countdown, iOS must NOT
    // start a second SpeechToText segment underneath that countdown. That second
    // segment was the source of duplicate text, restart callbacks, and the
    // countdown repeatedly dying at 3.
    if (!_restartAfterSilence) {
      _nativeRestartTimer?.cancel();
      _nativeRestartTimer = null;
      _nativeRestarting = false;
      _publishListening(false);
      return;
    }

    if (_nativeRestarting) return;
""",
    "freeze native recognizer after silence",
)

voice = replace_once(
    voice,
    """    _usingBrowser = false;
    _nativeRestarting = false;
    _segmentHasSpeech = false;
""",
    """    _usingBrowser = false;
    _nativeRestarting = false;
    _restartAfterSilence = true;
    _segmentHasSpeech = false;
""",
    "reset voice restart option",
)
voice_path.write_text(voice)


# Dashboard search -----------------------------------------------------------
glow_path = Path("lib/src/core/widgets/glow_search_bar.dart")
glow = glow_path.read_text()

glow = replace_once(
    glow,
    """      languageCode: _voiceLocale,
      owner: this,
      initialText: controller?.text ?? '',
""",
    """      languageCode: _voiceLocale,
      owner: this,
      initialText: controller?.text ?? '',
      restartAfterSilence: false,
""",
    "dashboard one-shot voice option",
)

old_submit = """  Future<void> _submitCapturedVoice() async {
    if (_voiceSubmitting) return;
    _voiceSubmitting = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    final controllerText = widget.controller?.text.trim() ?? '';
    final text = (_pendingVoiceSubmit?.trim().isNotEmpty ?? false)
        ? _pendingVoiceSubmit!.trim()
        : controllerText.isNotEmpty
        ? controllerText
        : _liveTranscript.trim();

    _pendingVoiceSubmit = null;
    setState(() {
      _countdown = null;
      _transcribing = false;
      _voiceLevel = 0;
    });
    _voiceSubmitting = false;

    if (text.isEmpty) {
      _showVoiceError('I did not catch that. Please try speaking again.');
      await _resumeListeningAfterSend();
      return;
    }

    final controller = widget.controller;
    if (controller != null) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    await _submitSearch(text);
  }
"""
new_submit = """  Future<void> _submitCapturedVoice() async {
    if (_voiceSubmitting) return;
    _voiceSubmitting = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    final controllerText = widget.controller?.text.trim() ?? '';
    final text = (_pendingVoiceSubmit?.trim().isNotEmpty ?? false)
        ? _pendingVoiceSubmit!.trim()
        : controllerText.isNotEmpty
        ? controllerText
        : _liveTranscript.trim();

    _pendingVoiceSubmit = null;

    // Critical iOS handoff: completely finish Apple/native speech recognition
    // BEFORE starting the AI request. The microphone must not be restarting or
    // publishing callbacks while the captured text is being submitted.
    _micSessionActive = false;
    await _voice.finish(owner: this);
    _stopMicBreathing();
    _restoreVoiceAudio();

    if (!mounted) {
      _voiceSubmitting = false;
      return;
    }
    setState(() {
      _countdown = null;
      _voiceActive = false;
      _transcribing = false;
      _voiceLevel = 0;
    });

    if (text.isEmpty) {
      _voiceSubmitting = false;
      _showVoiceError('I did not catch that. Please try speaking again.');
      return;
    }

    final controller = widget.controller;
    if (controller != null) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    // Unlock only after the recognizer is fully finished, then submit exactly
    // one request. Do not auto-restart the microphone after the AI responds.
    _voiceSubmitting = false;
    await _submitSearch(text);
  }
"""
glow = replace_once(glow, old_submit, new_submit, "dashboard native-to-AI submit handoff")

glow = replace_once(
    glow,
    """    final keepListening = _micSessionActive;

    if (wantsExplicitNavigation(input) && _runDirectSearch(input)) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (keepListening) await _resumeListeningAfterSend();
      return;
    }

    await _runInlineAi(input);
    FocusManager.instance.primaryFocus?.unfocus();
    if (keepListening) await _resumeListeningAfterSend();
""",
    """    if (wantsExplicitNavigation(input) && _runDirectSearch(input)) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    // One submitted phrase produces one dashboard AI request and one visible
    // response. Voice is intentionally stopped before this point on native iOS.
    await _runInlineAi(input);
    FocusManager.instance.primaryFocus?.unfocus();
""",
    "remove dashboard voice auto-resume after submit",
)

glow_path.write_text(glow)


# Intel Core ----------------------------------------------------------------
intel_path = Path("lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart")
intel = intel_path.read_text()

intel = replace_once(
    intel,
    """      languageCode: ref.read(voiceLanguageProvider).localeCode,
      owner: this,
      initialText: _controller.text,
""",
    """      languageCode: ref.read(voiceLanguageProvider).localeCode,
      owner: this,
      initialText: _controller.text,
      restartAfterSilence: false,
""",
    "Intel one-shot voice option",
)

pattern = r"""    String reply = '';
    final assistantId = _newId\(\);
    try \{
.*?
    \} on AiUnavailableException catch \(e\) \{"""
replacement = """    String reply = '';
    final assistantId = _newId();
    try {
      setState(() {
        _messages.add(
          IntelChatBubble(id: assistantId, role: 'assistant', content: ''),
        );
      });

      // Use the same reliable non-streaming concierge path as the dashboard.
      // The Edge Function currently returns JSON, so waiting on an SSE-style
      // streaming loop adds a second response brain without any user benefit.
      reply = await ref
          .read(aiEdgeRepositoryProvider)
          .chatConcierge(
            messages: history,
            character: _character == 'default' ? null : _character,
            locationContext: {
              'passportMode': false,
              'passportLabel': loc.label,
              'userLatitude': loc.latitude,
              'userLongitude': loc.longitude,
              'radiusKm': loc.radiusKm,
              'responseLanguage': ref.read(voiceLanguageProvider).displayName,
            },
            stream: false,
          );
      if (!mounted) return;
      final assistantIndex = _messages.indexWhere((m) => m.id == assistantId);
      if (assistantIndex >= 0) {
        setState(() {
          _messages[assistantIndex] = _messages[assistantIndex].copyWith(
            content: reply,
          );
        });
      }
    } on AiUnavailableException catch (e) {"""
intel = regex_once(intel, pattern, replacement, "Intel reliable AI response path")
intel_path.write_text(intel)


# AI handoff rules -----------------------------------------------------------
agents_path = Path("AGENTS.md")
agents = agents_path.read_text()
anchor = """### Voice countdown must survive native recognizer segment restarts
"""
insert = """### Native iOS/TestFlight voice is the acceptance target
- A PWA/web pass does **not** certify the voice flow. Always validate the native iOS/TestFlight path separately because Apple Speech recognition has different stop/restart behavior.
- Dashboard AI and Intel Core are one-shot hands-free voice entry points: speech -> silence -> freeze captured transcript -> visible 3 -> 2 -> 1 -> fully finish native recognizer -> exactly one AI submit -> visible reply.
- For those two entry points call `LiveVoiceInput.start(... restartAfterSilence: false)`. Never restart Apple/native recognition underneath an active auto-send countdown.
- Do not auto-resume the dashboard microphone after an AI answer. A new phrase starts from a new explicit microphone tap; this avoids duplicate recognizer sessions and repeated transcript text.
- The AI request must happen only after native voice has finished. A successful transcript with no `ai-concierge` request is a client handoff bug, not an AI-provider outage.
- Keep Intel Core on the same reliable non-streaming `chatConcierge(... stream: false)` response path unless the backend is changed to true streaming and native + web are both regression-tested.

"""
if insert not in agents:
    agents = replace_once(agents, anchor, insert + anchor, "AGENTS native iOS voice rules")
agents_path.write_text(agents)


# Force a distinct TestFlight binary ----------------------------------------
pub_path = Path("pubspec.yaml")
pub = pub_path.read_text()
pub = replace_once(pub, "version: 1.2.50+646", "version: 1.2.51+647", "Flutter build version")
pub_path.write_text(pub)

plist_path = Path("ios/Runner/Info.plist")
plist = plist_path.read_text()
plist = replace_once(plist, "<string>1.2.50</string>", "<string>1.2.51</string>", "iOS marketing version")
plist = replace_once(plist, "<string>646</string>", "<string>647</string>", "iOS build number")
plist_path.write_text(plist)

# Guard assertions -----------------------------------------------------------
assert voice.count("restartAfterSilence") >= 4
assert "restartAfterSilence: false" in glow
assert "await _voice.finish(owner: this);" in glow
assert "Do not auto-restart the microphone" in glow
assert "restartAfterSilence: false" in intel
assert "chatConciergeTokens(" not in intel
assert "chatConcierge(" in intel
assert "Native iOS/TestFlight voice is the acceptance target" in agents
assert "version: 1.2.51+647" in pub
assert "<string>647</string>" in plist
