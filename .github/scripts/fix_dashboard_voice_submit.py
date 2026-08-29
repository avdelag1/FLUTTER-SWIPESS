from pathlib import Path
import re


def once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing expected block: {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/core/widgets/glow_search_bar.dart')
s = path.read_text()

s = once(
    s,
    "  bool _voiceHasSpeech = false;\n",
    "  bool _voiceHasSpeech = false;\n"
    "  String _liveTranscript = '';\n"
    "  String? _pendingVoiceSubmit;\n"
    "  bool _voiceSubmitting = false;\n",
    'voice state fields',
)

countdown_block = r'''  void _beginVoiceCountdown() {
    if (!mounted ||
        !_voice.isOwnedBy(this) ||
        !_voice.active ||
        !_voiceHasSpeech ||
        _inlineAiLoading ||
        _countdown != null ||
        _voiceSubmitting) {
      return;
    }

    final controllerText = widget.controller?.text.trim() ?? '';
    final captured = controllerText.isNotEmpty
        ? controllerText
        : _liveTranscript.trim();
    if (captured.isEmpty) return;

    _pendingVoiceSubmit = captured;
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
      _voiceActive = false;
      _transcribing = false;
    });
    unawaited(AppHaptics.countdownTick(3));

    // Freeze the recognizer as soon as silence is confirmed. PWA/Chrome can
    // emit late duplicate/final callbacks after a phrase; keeping recognition
    // alive during the countdown could continuously re-arm the UI at "3".
    // We already captured the transcript, so stopping here makes 3-2-1
    // deterministic and guarantees the message reaches the dashboard AI.
    unawaited(_voice.finish(owner: this));

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
      unawaited(AppHaptics.voiceCommit());
      unawaited(_submitCapturedVoice());
    });
  }

  Future<void> _submitCapturedVoice() async {
    if (_voiceSubmitting) return;
    _voiceSubmitting = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    try {
      await _voice.finish(owner: this);
    } catch (_) {}

    if (!mounted) {
      _voiceSubmitting = false;
      _restoreVoiceAudio();
      return;
    }

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
      _voiceActive = false;
      _voiceLevel = 0;
      _voiceHasSpeech = false;
    });
    _restoreVoiceAudio();
    _voiceSubmitting = false;

    if (text.isEmpty) {
      _showVoiceError('I did not catch that. Please try speaking again.');
      return;
    }

    final controller = widget.controller;
    if (controller != null && controller.text.trim().isEmpty) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    _submitSearch(text);
  }
'''

s, n = re.subn(
    r"  void _beginVoiceCountdown\(\) \{.*?\n  Future<void> _finishVoiceAndSubmit\(\) async \{",
    countdown_block + "\n  Future<void> _finishVoiceAndSubmit() async {",
    s,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit('countdown function block not found')

s = once(
    s,
    "    final current = widget.controller?.text.trim() ?? '';\n"
    "    final text = current.isNotEmpty ? current : beforeFinish;\n",
    "    final current = widget.controller?.text.trim() ?? '';\n"
    "    final text = current.isNotEmpty\n"
    "        ? current\n"
    "        : _liveTranscript.trim().isNotEmpty\n"
    "        ? _liveTranscript.trim()\n"
    "        : beforeFinish;\n",
    'manual voice fallback text',
)

s = once(
    s,
    "    _voiceHasSpeech = false;\n"
    "    _cancelVoiceCountdown();\n",
    "    _voiceHasSpeech = false;\n"
    "    _liveTranscript = widget.controller?.text.trim() ?? '';\n"
    "    _pendingVoiceSubmit = null;\n"
    "    _cancelVoiceCountdown();\n",
    'voice start reset',
)

old_ontext = '''      onText: (text) {
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
'''
new_ontext = '''      onText: (text) {
        if (!mounted) return;
        final clean = text.trim();
        if (clean.isEmpty) return;
        _voiceHasSpeech = true;
        _liveTranscript = clean;

        // Once silence has started the 3-2-1 commit, ignore late recognizer
        // callbacks. The captured text is already frozen and will be sent.
        if (_countdown != null || _voiceSubmitting) return;

        if (controller != null) {
          controller.value = TextEditingValue(
            text: clean,
            selection: TextSelection.collapsed(offset: clean.length),
          );
          widget.onChanged?.call(clean);
        }
        setState(() {
          _voiceActive = true;
          _transcribing = false;
        });
      },
'''
s = once(s, old_ontext, new_ontext, 'live onText handler')

s = once(
    s,
    "    setState(() {\n"
    "      _inlineAiLoading = true;\n"
    "      _inlineQuestion = input;\n"
    "      _inlineAnswer = null;\n"
    "      _inlineLocalBrain = const [];\n"
    "    });\n",
    "    setState(() {\n"
    "      _inlineAiLoading = true;\n"
    "      _inlineQuestion = input;\n"
    "      _inlineAnswer = null;\n"
    "      _inlineLocalBrain = const [];\n"
    "      _liveTranscript = '';\n"
    "    });\n",
    'clear live transcript when sending',
)

# The arrow must still send the captured transcript if a browser/PWA clears the
# TextEditingController during an IME/recognizer handoff.
s = once(
    s,
    "                  onPressed: () => _submitSearch(widget.controller?.text ?? ''),\n",
    "                  onPressed: () {\n"
    "                    final typed = widget.controller?.text.trim() ?? '';\n"
    "                    _submitSearch(typed.isNotEmpty ? typed : _liveTranscript);\n"
    "                  },\n",
    'arrow fallback submit',
)

# Replace the generic voice status with the actual live transcript whenever it
# exists, so users can literally see recognition happening word-by-word.
old_status = '''              child: Text(
                _countdown != null
                    ? 'Silence detected · sending in $_countdown…'
                    : 'Listening… speak naturally',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
'''
new_status = '''              child: Text(
                _countdown != null
                    ? _liveTranscript.trim().isNotEmpty
                          ? '“${_liveTranscript.trim()}” · sending in $_countdown…'
                          : 'Silence detected · sending in $_countdown…'
                    : _liveTranscript.trim().isNotEmpty
                    ? 'LIVE · ${_liveTranscript.trim()}'
                    : 'Listening… speak naturally',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: _liveTranscript.trim().isNotEmpty && _countdown == null
                      ? ink.withAlpha(225)
                      : blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  height: 1.25,
                ),
              ),
'''
s = once(s, old_status, new_status, 'voice live status')

path.write_text(s)

# Make silence detection responsive in PWA/native without being so aggressive
# that normal speaking pauses are cut off. The 3-second visible countdown still
# provides a clear confirmation window.
path = Path('lib/src/features/ai/presentation/services/live_voice_input.dart')
s = path.read_text()
s = s.replace(
    '  static const silenceBeforeCountdown = Duration(milliseconds: 2800);\n\n'
    '  Duration get _effectiveSilenceBeforeCountdown =>\n'
    '      kIsWeb ? const Duration(milliseconds: 4500) : silenceBeforeCountdown;\n',
    '  static const silenceBeforeCountdown = Duration(milliseconds: 2200);\n\n'
    '  Duration get _effectiveSilenceBeforeCountdown =>\n'
    '      kIsWeb ? const Duration(milliseconds: 2200) : silenceBeforeCountdown;\n',
    1,
)
path.write_text(s)
