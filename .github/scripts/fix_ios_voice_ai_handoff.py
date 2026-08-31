from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


# Browser interface ---------------------------------------------------------
stub_path = Path("lib/src/features/ai/presentation/services/browser_live_speech_stub.dart")
stub = stub_path.read_text()
stub = replace_once(
    stub,
    "typedef BrowserSpeechSilenceCallback = void Function();\n",
    "typedef BrowserSpeechSilenceCallback = void Function();\n"
    "typedef BrowserSpeechActivityCallback = void Function();\n",
    "browser speech activity typedef",
)
stub = replace_once(
    stub,
    "    BrowserSpeechSilenceCallback? onSilence,\n",
    "    BrowserSpeechSilenceCallback? onSilence,\n"
    "    BrowserSpeechActivityCallback? onSpeechActivity,\n",
    "browser stub activity callback",
)
stub_path.write_text(stub)


# Browser implementation ----------------------------------------------------
web_speech_path = Path(
    "lib/src/features/ai/presentation/services/browser_live_speech_web.dart"
)
web_speech = web_speech_path.read_text()
web_speech = replace_once(
    web_speech,
    "  BrowserSpeechSilenceCallback? _onSilence;\n",
    "  BrowserSpeechSilenceCallback? _onSilence;\n"
    "  BrowserSpeechActivityCallback? _onSpeechActivity;\n",
    "browser activity field",
)
web_speech = replace_once(
    web_speech,
    "    BrowserSpeechSilenceCallback? onSilence,\n",
    "    BrowserSpeechSilenceCallback? onSilence,\n"
    "    BrowserSpeechActivityCallback? onSpeechActivity,\n",
    "browser web activity callback",
)
web_speech = replace_once(
    web_speech,
    "    _onSilence = onSilence;\n",
    "    _onSilence = onSilence;\n"
    "    _onSpeechActivity = onSpeechActivity;\n",
    "browser activity assignment",
)
web_speech = replace_once(
    web_speech,
    "    // Poll the JS event queue every 80ms.\n"
    "    _pollTimer?.cancel();\n"
    "    _pollTimer = Timer.periodic(const Duration(milliseconds: 80), _poll);\n",
    "    // Keep resumed speech responsive enough to interrupt 3 -> 2 -> 1.\n"
    "    _pollTimer?.cancel();\n"
    "    _pollTimer = Timer.periodic(const Duration(milliseconds: 35), _poll);\n",
    "faster browser event polling",
)
web_speech = replace_once(
    web_speech,
    "      case 'silence':\n"
    "        _onSilence?.call();\n"
    "      case 'error':\n",
    "      case 'silence':\n"
    "        _onSilence?.call();\n"
    "      case 'speech':\n"
    "        _onSpeechActivity?.call();\n"
    "      case 'error':\n",
    "browser speech event dispatch",
)
web_speech = replace_once(
    web_speech,
    "    _onSilence = null;\n",
    "    _onSilence = null;\n"
    "    _onSpeechActivity = null;\n",
    "browser activity cleanup",
)
web_speech_path.write_text(web_speech)


# Shared voice coordinator --------------------------------------------------
voice_path = Path("lib/src/features/ai/presentation/services/live_voice_input.dart")
voice = voice_path.read_text()
voice = replace_once(
    voice,
    "  VoidCallback? _onSilence;\n"
    "  ValueChanged<String>? _onError;\n",
    "  VoidCallback? _onSilence;\n"
    "  VoidCallback? _onSpeechActivity;\n"
    "  ValueChanged<String>? _onError;\n",
    "voice speech activity field",
)
voice = replace_once(
    voice,
    "    required VoidCallback onSilence,\n"
    "    ValueChanged<bool>? onListeningChanged,\n",
    "    required VoidCallback onSilence,\n"
    "    VoidCallback? onSpeechActivity,\n"
    "    ValueChanged<bool>? onListeningChanged,\n",
    "voice start speech activity argument",
)
voice = replace_once(
    voice,
    "    _onSilence = onSilence;\n"
    "    _onListeningChanged = onListeningChanged;\n",
    "    _onSilence = onSilence;\n"
    "    _onSpeechActivity = onSpeechActivity;\n"
    "    _onListeningChanged = onListeningChanged;\n",
    "voice speech activity assignment",
)
voice = replace_once(
    voice,
    "          onSilence: () {\n"
    "            if (!_active || _intentionalStop || !_usingBrowser) return;\n"
    "            // The JS bridge reports a segment pause quickly (especially on\n"
    "            // mobile Chrome/PWA). Treat that as a hint, not as permission to\n"
    "            // send immediately. Re-arm the Dart silence window so ordinary\n"
    "            // pauses between words do not start the countdown too early.\n"
    "            _armBrowserSilence();\n"
    "          },\n"
    "          onListening: (listening) {\n",
    "          onSilence: () {\n"
    "            if (!_active || _intentionalStop || !_usingBrowser) return;\n"
    "            // The JS bridge reports a segment pause quickly (especially on\n"
    "            // mobile Chrome/PWA). Treat that as a hint, not as permission to\n"
    "            // send immediately. Re-arm the Dart silence window so ordinary\n"
    "            // pauses between words do not start the countdown too early.\n"
    "            _armBrowserSilence();\n"
    "          },\n"
    "          onSpeechActivity: () {\n"
    "            if (!_active || _intentionalStop || !_usingBrowser) return;\n"
    "            _browserSilenceTimer?.cancel();\n"
    "            _browserSilenceTimer = null;\n"
    "            _segmentHasSpeech = true;\n"
    "            _silenceDeliveredForSegment = false;\n"
    "            _onSpeechActivity?.call();\n"
    "          },\n"
    "          onListening: (listening) {\n",
    "wire browser speech activity",
)
voice = replace_once(
    voice,
    "    _nativeSessionText = speech;\n"
    "    _segmentHasSpeech = true;\n",
    "    _nativeSessionText = speech;\n"
    "    _segmentHasSpeech = true;\n"
    "    _onSpeechActivity?.call();\n",
    "native recognized speech activity",
)
voice = replace_once(
    voice,
    "    _onSilence = null;\n"
    "    _onError = null;\n",
    "    _onSilence = null;\n"
    "    _onSpeechActivity = null;\n"
    "    _onError = null;\n",
    "voice activity cleanup",
)
voice_path.write_text(voice)


# Dashboard AI field --------------------------------------------------------
glow_path = Path("lib/src/core/widgets/glow_search_bar.dart")
glow = glow_path.read_text()
helper_anchor = "  Future<void> _finalizeVoiceBeforeSubmit() async {\n"
helper = """  void _handleSpeechActivity() {
    if (!mounted || !_micSessionActive || _voiceSubmitting) return;
    _resetIdleTimeout();
    _startRouteCheck();

    if (_countdown != null) {
      final controllerText = widget.controller?.text.trim() ?? '';
      final baseline = (_pendingVoiceSubmit?.trim().isNotEmpty ?? false)
          ? _pendingVoiceSubmit!.trim()
          : controllerText.isNotEmpty
          ? controllerText
          : _liveTranscript.trim();
      _speechResumedWithoutText = baseline.isNotEmpty;
      _speechResumeBaseline = baseline;
      _pendingVoiceSubmit = null;
      _cancelVoiceCountdown();
    }

    if (!_voiceActive || _transcribing) {
      setState(() {
        _voiceActive = true;
        _transcribing = false;
      });
    }
  }

"""
if helper not in glow:
    glow = replace_once(
        glow,
        helper_anchor,
        helper + helper_anchor,
        "dashboard speech activity helper",
    )
glow = replace_once(
    glow,
    "      restartAfterSilence: true,\n"
    "      onText: (text) {\n",
    "      restartAfterSilence: true,\n"
    "      onSpeechActivity: _handleSpeechActivity,\n"
    "      onText: (text) {\n",
    "dashboard speech activity callback",
)
glow_path.write_text(glow)


# Intel Core ----------------------------------------------------------------
intel_path = Path("lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart")
intel = intel_path.read_text()
intel = replace_once(
    intel,
    "      restartAfterSilence: false,\n"
    "      onText: (text) {\n",
    "      restartAfterSilence: true,\n"
    "      onSpeechActivity: () {\n"
    "        if (!mounted) return;\n"
    "        _cancelCountdown();\n"
    "        setState(() => _recording = true);\n"
    "      },\n"
    "      onText: (text) {\n",
    "Intel resumed speech callback",
)
intel_path.write_text(intel)


# Web SpeechRecognition bridge ---------------------------------------------
index_path = Path("web/index.html")
index = index_path.read_text()
index = replace_once(
    index,
    "      var restartDelay = isMobile ? 380 : 120;\n"
    "      var maxRestartAttempts = 12;\n",
    "      var restartDelay = isMobile ? 180 : 90;\n"
    "      var maxRestartAttempts = 60;\n",
    "web recognizer restart aggressiveness",
)
index = replace_once(
    index,
    "        }, 900);\n"
    "      }\n\n"
    "      // Shared event queue. Dart drains this via polling.\n",
    "        }, 1200);\n"
    "      }\n\n"
    "      // Shared event queue. Dart drains this via polling.\n",
    "web silence debounce",
)
index = replace_once(
    index,
    "        try { recognition.onstart = null; } catch(e) {}\n"
    "        try { recognition.onresult = null; } catch(e) {}\n",
    "        try { recognition.onstart = null; } catch(e) {}\n"
    "        try { recognition.onsoundstart = null; } catch(e) {}\n"
    "        try { recognition.onspeechstart = null; } catch(e) {}\n"
    "        try { recognition.onspeechend = null; } catch(e) {}\n"
    "        try { recognition.onresult = null; } catch(e) {}\n",
    "dispose browser speech handlers",
)
index = replace_once(
    index,
    "          recognition.onspeechstart = function () {\n"
    "            if (!active || intentionalStop) return;\n"
    "            push('listening', 'true');\n"
    "          };\n\n"
    "          recognition.onresult = function (event) {\n"
    "            if (!active || intentionalStop) return;\n"
    "            try {\n",
    "          recognition.onsoundstart = function () {\n"
    "            if (!active || intentionalStop) return;\n"
    "            clearTimeout(segmentSilenceTimer);\n"
    "          };\n\n"
    "          recognition.onspeechstart = function () {\n"
    "            if (!active || intentionalStop) return;\n"
    "            clearTimeout(segmentSilenceTimer);\n"
    "            push('listening', 'true');\n"
    "            push('speech', 'start');\n"
    "          };\n\n"
    "          recognition.onspeechend = function () {\n"
    "            if (!active || intentionalStop) return;\n"
    "            scheduleSegmentSilence();\n"
    "          };\n\n"
    "          recognition.onresult = function (event) {\n"
    "            if (!active || intentionalStop) return;\n"
    "            clearTimeout(segmentSilenceTimer);\n"
    "            try {\n",
    "browser speech start/end detection",
)
index = replace_once(
    index,
    "          clearTimeout(restartTimer);\n"
    "          disposeRecognition();\n"
    "          active = true;\n",
    "          clearTimeout(restartTimer);\n"
    "          clearTimeout(segmentSilenceTimer);\n"
    "          disposeRecognition();\n"
    "          active = true;\n",
    "clear silence timer at browser start",
)
index = replace_once(
    index,
    "          clearTimeout(restartTimer);\n"
    "          try { if (recognition) recognition.stop(); } catch(e) {}\n",
    "          clearTimeout(restartTimer);\n"
    "          clearTimeout(segmentSilenceTimer);\n"
    "          try { if (recognition) recognition.stop(); } catch(e) {}\n",
    "clear silence timer at browser stop",
)
index = replace_once(
    index,
    "          clearTimeout(restartTimer);\n"
    "          disposeRecognition();\n"
    "          push('listening', 'false');\n"
    "        }\n",
    "          clearTimeout(restartTimer);\n"
    "          clearTimeout(segmentSilenceTimer);\n"
    "          disposeRecognition();\n"
    "          push('listening', 'false');\n"
    "        }\n",
    "clear silence timer at browser abort",
)
index_path.write_text(index)


# Project voice guardrails --------------------------------------------------
agents_path = Path("AGENTS.md")
agents = agents_path.read_text()
agents = replace_once(
    agents,
    "- Dashboard AI and Intel Core are one-shot hands-free voice entry points: speech -> silence -> freeze captured transcript -> visible 3 -> 2 -> 1 -> fully finish native recognizer -> exactly one AI submit -> visible reply.\n"
    "- For those two entry points call `LiveVoiceInput.start(... restartAfterSilence: false)`. Never restart Apple/native recognition underneath an active auto-send countdown.\n",
    "- Dashboard AI and Intel Core stay armed while the user is composing by voice: speech -> real silence -> visible 3 -> 2 -> 1. If the user speaks again during that countdown, cancel auto-send immediately, keep listening, and keep extending the same transcript. After a committed send, the mic stays off until the next explicit tap.\n"
    "- For those entry points keep recognition restart enabled across short browser/native segment boundaries. A recognizer segment ending is not the same thing as the user being finished speaking.\n",
    "update continuous voice contract",
)
agents = replace_once(
    agents,
    "- **Only actual new recognized transcript text may cancel an active 3 -> 2 -> 1 countdown.** Native `onSoundLevel` / microphone-energy spikes are noisy and can fire when the recognizer restarts after silence; they must never cancel auto-send.\n",
    "- Confirmed browser `onspeechstart`, genuinely new recognized transcript, or sustained adaptive voice activity may cancel an active 3 -> 2 -> 1 countdown. A single raw microphone-energy spike must never cancel auto-send.\n",
    "update speech resume guardrail",
)
agents_path.write_text(agents)


# Guard assertions ----------------------------------------------------------
assert "BrowserSpeechActivityCallback" in stub
assert "case 'speech'" in web_speech
assert "onSpeechActivity" in voice
assert "onSpeechActivity: _handleSpeechActivity" in glow
assert "restartAfterSilence: true" in intel
assert "onSpeechActivity:" in intel
assert "push('speech', 'start')" in index
assert "recognition.onspeechend" in index
assert "widget.controller?.clear();" not in glow
assert "sustained adaptive voice activity" in agents
