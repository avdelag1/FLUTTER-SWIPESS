from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


path = Path("lib/src/core/widgets/glow_search_bar.dart")
src = path.read_text()

old_level = """  void _handleVoiceLevel(double normalized, {double? rawLevel}) {
    if (!mounted) return;
    final speaking = normalized > 0.025 || (rawLevel != null && rawLevel > -60);
    if (_countdown != null && speaking) {
      _cancelVoiceCountdown();
      setState(() => _voiceActive = true);
    }
    if ((_voiceLevel - normalized).abs() > .01) {
      setState(() => _voiceLevel = normalized);
    }
  }
"""
new_level = """  void _handleVoiceLevel(double normalized) {
    if (!mounted) return;
    // Native recognizers can emit a brief sound-level spike while a finished
    // speech segment is restarting. That is not proof the user spoke again and
    // must never cancel the 3 -> 2 -> 1 auto-send countdown. Only a real new
    // transcript callback is allowed to cancel an active countdown.
    if ((_voiceLevel - normalized).abs() > .01) {
      setState(() => _voiceLevel = normalized);
    }
  }
"""
src = replace_once(src, old_level, new_level, "voice-level countdown cancellation")

old_result = """      onText: (text) {
        if (!mounted || _voiceSubmitting) return;
        if (_countdown != null) _cancelVoiceCountdown();
        _liveTranscript = text;
"""
new_result = """      onText: (text) {
        if (!mounted || _voiceSubmitting) return;
        final cleanText = text.trim();
        final pendingText = _pendingVoiceSubmit?.trim();
        // A recognizer restart can occasionally re-publish the same committed
        // phrase. Do not treat that as fresh speech. A genuinely changed
        // transcript still cancels auto-send immediately so the user can keep
        // talking naturally.
        if (_countdown != null &&
            cleanText.isNotEmpty &&
            cleanText != pendingText) {
          _cancelVoiceCountdown();
        }
        _liveTranscript = text;
"""
src = replace_once(src, old_result, new_result, "recognized-text countdown cancellation")

old_sound = """      onSoundLevel: (level) {
        if (!mounted) return;
        final normalized = ((level + 45) / 45).clamp(0.0, 1.0).toDouble();
        _handleVoiceLevel(normalized, rawLevel: level);
      },
"""
new_sound = """      onSoundLevel: (level) {
        if (!mounted) return;
        final normalized = ((level + 45) / 45).clamp(0.0, 1.0).toDouble();
        _handleVoiceLevel(normalized);
      },
"""
src = replace_once(src, old_sound, new_sound, "sound-level callback")

old_error = """      onError: (message) {
        if (!mounted) return;
        _cancelVoiceCountdown();
        unawaited(_voice.cancel(owner: this));
        _micSessionActive = false;
        setState(() {
          _voiceActive = false;
          _transcribing = false;
          _voiceLevel = 0;
        });
        _stopMicBreathing();
        _restoreVoiceAudio();
        _showVoiceError(message);
      },
"""
new_error = """      onError: (message) {
        if (!mounted) return;
        final countdownOwnsCapturedText =
            _countdown != null &&
            (_pendingVoiceSubmit?.trim().isNotEmpty ?? false);
        if (countdownOwnsCapturedText) {
          // Once silence has captured valid text and started 3 -> 2 -> 1, a
          // recognizer shutdown/restart error must not abort the auto-sender.
          // The timer is now authoritative and will submit the captured text.
          setState(() {
            _voiceActive = false;
            _transcribing = false;
            _voiceLevel = 0;
          });
          return;
        }
        _cancelVoiceCountdown();
        unawaited(_voice.cancel(owner: this));
        _micSessionActive = false;
        setState(() {
          _voiceActive = false;
          _transcribing = false;
          _voiceLevel = 0;
        });
        _stopMicBreathing();
        _restoreVoiceAudio();
        _showVoiceError(message);
      },
"""
src = replace_once(src, old_error, new_error, "countdown error ownership")

path.write_text(src)

agents_path = Path("AGENTS.md")
agents = agents_path.read_text()
old_rule = "- Speaking again during the countdown must still cancel countdown and continue the same transcript.\n"
new_rule = """- Speaking again during the countdown must still cancel countdown and continue the same transcript.
- **Only actual new recognized transcript text may cancel an active 3 -> 2 -> 1 countdown.** Native `onSoundLevel` / microphone-energy spikes are noisy and can fire when the recognizer restarts after silence; they must never cancel auto-send.
- Once valid text has been captured and the countdown has started, a recognizer stop/restart error must not abort that countdown. The countdown owns the captured text and must reach 3 -> 2 -> 1 -> submit unless genuinely new transcript text arrives or the user explicitly cancels.
"""
agents = replace_once(agents, old_rule, new_rule, "AGENTS auto-sender guardrail")
agents_path.write_text(agents)

assert "_handleVoiceLevel(normalized);" in src
assert "countdownOwnsCapturedText" in src
assert "cleanText != pendingText" in src
assert "Only actual new recognized transcript text" in agents
