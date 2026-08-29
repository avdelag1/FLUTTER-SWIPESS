from pathlib import Path
import re


def once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing expected block: {label}')
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'missing/ambiguous regex block: {label} ({count})')
    return updated


path = Path('lib/src/core/widgets/glow_search_bar.dart')
s = path.read_text()

# Android should use the existing continuous speech_to_text coordinator so the
# dashboard gets real partial words while the person is still talking. Keep the
# high-accuracy Whisper recorder on iOS, where it is already the safer fallback.
s = once(
    s,
    "import 'package:flutter/foundation.dart' show kIsWeb;\n",
    "import 'package:flutter/foundation.dart'\n"
    "    show TargetPlatform, defaultTargetPlatform, kIsWeb;\n",
    'foundation import',
)

s = once(
    s,
    "  static const _recordRed = Color(0xFFFF1F1F);\n"
    "  static const _recordRedDeep = Color(0xFFCC0000);\n",
    "  // Bright coral-red reads as active/recording without the harsh blood-red UI.\n"
    "  static const _recordRed = Color(0xFFFF4D6D);\n"
    "  static const _recordRedDeep = Color(0xFFE11D48);\n",
    'recording colors',
)

s = once(
    s,
    "  bool get _isRecordingGlow =>\n"
    "      _isListeningSession && _countdown == null && !_transcribing;\n\n",
    "  bool get _isRecordingGlow =>\n"
    "      _isListeningSession && _countdown == null && !_transcribing;\n\n"
    "  // Android + web provide true live partial transcription. iOS stays on\n"
    "  // the Whisper recorder path for accuracy/stability.\n"
    "  bool get _useLiveSpeech =>\n"
    "      kIsWeb ||\n"
    "      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);\n\n",
    'live speech platform getter',
)

# A refined mushroom-style pop: quick growth, tiny settle, then a restrained
# breathing pulse while active. It feels physical without looking cartoonish.
s = regex_once(
    s,
    r"    _micPopCtrl = AnimationController\(\n.*?    _focusNode.addListener\(_refresh\);",
    """    _micPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _micPopScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.84, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.28, end: 0.99)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.99, end: 1.07)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 24,
      ),
    ]).animate(_micPopCtrl);
    _micBreathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
    _micBreathScale = Tween<double>(begin: 1.0, end: 1.045).animate(
      CurvedAnimation(parent: _micBreathCtrl, curve: Curves.easeInOutCubic),
    );
    _focusNode.addListener(_refresh);""",
    'mic animation setup',
)

s = once(
    s,
    "  void _stopMicBreathing() {\n"
    "    if (_micBreathCtrl.isAnimating) {\n"
    "      _micBreathCtrl.stop();\n"
    "      _micBreathCtrl.value = 0;\n"
    "    }\n"
    "  }\n",
    "  void _stopMicBreathing() {\n"
    "    if (_micBreathCtrl.isAnimating) {\n"
    "      _micBreathCtrl.stop();\n"
    "      _micBreathCtrl.value = 0;\n"
    "    }\n"
    "    if (_micPopCtrl.value > 0) {\n"
    "      unawaited(\n"
    "        _micPopCtrl.animateBack(\n"
    "          0,\n"
    "          duration: const Duration(milliseconds: 190),\n"
    "          curve: Curves.easeOutCubic,\n"
    "        ),\n"
    "      );\n"
    "    }\n"
    "  }\n",
    'mic settle on stop',
)

# Use continuous platform speech on Android anywhere this widget previously
# selected the web recognizer path. This keeps listening across natural pauses
# and gives live words in the one search field instead of a second transcript.
web_branch_count = s.count('if (kIsWeb) {')
if web_branch_count < 4:
    raise SystemExit(f'unexpected kIsWeb branch count: {web_branch_count}')
s = s.replace('if (kIsWeb) {', 'if (_useLiveSpeech) {')

# Quieter voices should still cancel silence/countdown. The old -54 dB gate was
# too aggressive on phones with noise suppression.
s = once(
    s,
    "    final speaking = normalized > 0.06 ||\n"
    "        (rawLevel != null && rawLevel > -54);\n",
    "    final speaking = normalized > 0.025 ||\n"
    "        (rawLevel != null && rawLevel > -60);\n",
    'speech activity threshold',
)

# iOS/Whisper path: require a genuine natural pause before countdown. Android
# uses LiveVoiceInput below and gets the same 3.5s behavior there.
s = once(
    s,
    "    _silenceTimer = Timer(const Duration(milliseconds: 2200), () {\n",
    "    _silenceTimer = Timer(const Duration(milliseconds: 3500), () {\n",
    'whisper silence duration',
)

# Native Whisper has no partial transcript before stop(), so an empty captured
# string must not block the countdown on iOS. Live speech still requires text.
s = once(
    s,
    "    final captured = controllerText.isNotEmpty\n"
    "        ? controllerText\n"
    "        : _liveTranscript.trim();\n"
    "    if (captured.isEmpty) return;\n\n"
    "    _pendingVoiceSubmit = captured;\n",
    "    final captured = controllerText.isNotEmpty\n"
    "        ? controllerText\n"
    "        : _liveTranscript.trim();\n"
    "    if (_useLiveSpeech && captured.isEmpty) return;\n\n"
    "    _pendingVoiceSubmit = captured.isEmpty ? null : captured;\n",
    'native countdown capture gate',
)

# Replace the mic itself so 3/2/1 lives ONLY inside the mic button. The active
# control grows a little, pops once, breathes subtly, and uses a soft coral glow.
new_mic = r'''  Widget _micButton({required bool isLight, required Color blue}) {
    final sessionActive = _micSessionActive;
    final glow = sessionActive ? _recordRed : blue;
    final deepGlow = sessionActive ? _recordRedDeep : blue;
    final pulse = 1.0 + (_voiceLevel * .035);
    final diameter = sessionActive ? 31.0 : 28.0;

    return Semantics(
      button: true,
      label: _countdown != null
          ? 'Voice search sends in $_countdown'
          : sessionActive
          ? 'Stop voice search'
          : 'Start voice search',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleVoice,
        child: AnimatedBuilder(
          animation: Listenable.merge([_micPopCtrl, _micBreathCtrl]),
          builder: (context, child) {
            final pop = _micPopCtrl.isAnimating || _micPopCtrl.value > 0
                ? _micPopScale.value
                : 1.0;
            final breath = _isRecordingGlow ? _micBreathScale.value : 1.0;
            final scale = pop * breath * (sessionActive ? pulse : 1.0);

            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  color: sessionActive
                      ? glow.withAlpha(245)
                      : blue.withAlpha(isLight ? 18 : 34),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sessionActive
                        ? Colors.white.withAlpha(78)
                        : blue.withAlpha(90),
                    width: sessionActive ? 1.1 : 1,
                  ),
                  boxShadow: sessionActive
                      ? [
                          BoxShadow(
                            color: glow.withAlpha(100),
                            blurRadius: 15 + (_voiceLevel * 9),
                            spreadRadius: .5 + (_voiceLevel * 1.2),
                          ),
                          BoxShadow(
                            color: deepGlow.withAlpha(48),
                            blurRadius: 27 + (_voiceLevel * 7),
                            spreadRadius: -4,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: _transcribing
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : _countdown != null
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: Text(
                          '$_countdown',
                          key: ValueKey<int>(_countdown!),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16.5,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : sessionActive
                    ? const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 17,
                      )
                    : Icon(Icons.mic_none_rounded, color: blue, size: 16),
              ),
            );
          },
        ),
      ),
    );
  }
'''
s = regex_once(
    s,
    r"  Widget _micButton\(\{required bool isLight, required Color blue\}\) \{.*?\n  Widget _inlineAiPanel",
    new_mic + "\n  Widget _inlineAiPanel",
    'mic button function',
)

# The whole search pill expands by only 4 px with an ease-out-back curve: enough
# to communicate microphone activation without jumping the dashboard layout.
s = once(
    s,
    "          AnimatedContainer(\n"
    "            duration: const Duration(milliseconds: 180),\n"
    "            height: 44,\n",
    "          AnimatedContainer(\n"
    "            duration: Duration(milliseconds: voiceVisible ? 360 : 220),\n"
    "            curve: voiceVisible ? Curves.easeOutBack : Curves.easeOutCubic,\n"
    "            height: voiceVisible ? 48 : 44,\n",
    'search pill activation geometry',
)

s = once(
    s,
    "                color: voiceVisible\n"
    "                    ? sessionGlow\n"
    "                    : blue.withAlpha(isLight ? 125 : 145),\n"
    "                width: voiceVisible ? 2 : .9,\n",
    "                color: voiceVisible\n"
    "                    ? sessionGlow.withAlpha(210)\n"
    "                    : blue.withAlpha(isLight ? 125 : 145),\n"
    "                width: voiceVisible ? 1.35 : .9,\n",
    'search pill active border',
)

s = once(
    s,
    "                      BoxShadow(\n"
    "                        color: sessionGlow.withAlpha(72),\n"
    "                        blurRadius: 18 + (_voiceLevel * 10),\n"
    "                        spreadRadius: -1,\n"
    "                      ),\n"
    "                      BoxShadow(\n"
    "                        color: sessionGlowDeep.withAlpha(48),\n"
    "                        blurRadius: 28 + (_voiceLevel * 6),\n"
    "                        spreadRadius: -4,\n"
    "                      ),\n",
    "                      BoxShadow(\n"
    "                        color: sessionGlow.withAlpha(52),\n"
    "                        blurRadius: 20 + (_voiceLevel * 8),\n"
    "                        spreadRadius: -2,\n"
    "                      ),\n"
    "                      BoxShadow(\n"
    "                        color: sessionGlowDeep.withAlpha(28),\n"
    "                        blurRadius: 34 + (_voiceLevel * 5),\n"
    "                        spreadRadius: -7,\n"
    "                      ),\n",
    'search pill active glow',
)

# Remove the giant center-of-field countdown. Numbers now exist only in mic.
s = regex_once(
    s,
    r"                      if \(_countdown != null\)\n                        Positioned\.fill\(.*?\n                      TextField\(",
    "                      TextField(",
    'center countdown overlay',
)

# Keep exactly one voice status surface: the TextField. No secondary countdown
# hint is allowed in the search text itself.
s = regex_once(
    s,
    r"                          hintText: _countdown != null\n.*?                          hintStyle: GoogleFonts\.plusJakartaSans\(\n.*?                          \),\n                          border: InputBorder\.none,",
    """                          hintText: _transcribing
                              ? 'Transcribing your voice…'
                              : _voiceActive &&
                                    (widget.controller?.text.trim().isEmpty ??
                                        true)
                              ? 'Listening… speak naturally'
                              : null,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: sessionGlow.withAlpha(205),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,""",
    'single in-field voice hint',
)

# Delete the duplicate transcript/status line below the pill entirely.
s = regex_once(
    s,
    r"          if \(voiceVisible\) \.\.\.\[\n.*?\n          \],\n          _inlineAiPanel",
    "          _inlineAiPanel",
    'duplicate voice status row',
)

# Sanity guards: no visible search-field countdown copy should survive.
if "Sending in $_countdown" in s or "Silence detected · sending in $_countdown" in s:
    raise SystemExit('duplicate visible countdown text survived patch')
if "LIVE · ${_liveTranscript.trim()}" in s:
    raise SystemExit('duplicate live transcript row survived patch')

path.write_text(s)

# Continuous speech coordinator: restore the natural 3.5 second silence window
# promised by its own documentation. Speech that resumes during 3/2/1 still
# cancels countdown immediately via the dashboard onText/onSoundLevel handlers.
path = Path('lib/src/features/ai/presentation/services/live_voice_input.dart')
s = path.read_text()
s = once(
    s,
    "  static const silenceBeforeCountdown = Duration(milliseconds: 2200);\n\n"
    "  Duration get _effectiveSilenceBeforeCountdown =>\n"
    "      kIsWeb ? const Duration(milliseconds: 2200) : silenceBeforeCountdown;\n",
    "  static const silenceBeforeCountdown = Duration(milliseconds: 3500);\n\n"
    "  Duration get _effectiveSilenceBeforeCountdown =>\n"
    "      kIsWeb ? const Duration(milliseconds: 3500) : silenceBeforeCountdown;\n",
    'continuous speech silence window',
)
path.write_text(s)
