import re

with open('lib/src/features/ai/presentation/services/live_voice_input.dart', 'r') as f:
    code = f.read()

# We will completely remove _listenToAmplitude's timer logic and _armBrowserSilence.
# We will use one unified _silenceTimer.

new_class = '''  Timer? _silenceTimer;

  void _armSilence() {
    _silenceTimer?.cancel();
    if (!_active || _intentionalStop) return;
    _silenceTimer = Timer(silenceBeforeCountdown, () {
      if (!_active || _intentionalStop) return;
      if (_usingBrowser) {
        _onSilence?.call();
      } else {
        unawaited(_finalizeSegment(
          restart: true,
          triggerSilence: true,
          forceTranscribe: false,
        ));
      }
    });
  }'''

code = code.replace('  Timer? _browserSilenceTimer;', '  Timer? _silenceTimer;')
# We need to replace all instances of _browserSilenceTimer with _silenceTimer
code = code.replace('_browserSilenceTimer', '_silenceTimer')
code = code.replace('_silenceFinalizeTimer', '_silenceTimer')

# Now rewrite _listenToAmplitude to only publish sound level, no timer logic!
old_listen = r'''  void _listenToAmplitude\(\) \{\n.*?\}\n\n  Future<void> _finalizeSegment'''
new_listen = '''  void _listenToAmplitude() {
    unawaited(_amplitudeSubscription?.cancel());
    _amplitudeSubscription = _nativeVoice
        .amplitudeStream(interval: const Duration(milliseconds: 80))
        .listen(
          (amplitude) {
            if (!_active || _intentionalStop || _finalizing) return;
            final level = amplitude.current.isFinite ? amplitude.current : -60.0;
            _publishSoundLevel(level);
          },
          onError: (_) {
            if (_active && !_usingBrowser) {
              _onError?.call('Voice recording stopped.');
            }
          },
        );
  }

  Future<void> _finalizeSegment'''
code = re.sub(old_listen, new_listen, code, flags=re.DOTALL)

# In start(), arm the silence timer immediately.
code = code.replace('_publishListening(true);', '_publishListening(true);\n      _armSilence();')

# In onText, arm the silence timer.
code = code.replace('_armBrowserSilence();', '_armSilence();')
code = code.replace('void _armBrowserSilence() {', 'void _armSilence() {')
# Replace the old _armSilence body
old_arm = r'''  void _armSilence\(\) \{\n    if \(!_active \|\| !_usingBrowser \|\| !_segmentHasSpeech\) return;\n    _silenceTimer\?\.cancel\(\);\n    _silenceTimer = Timer\(silenceBeforeCountdown, \(\) \{\n      _silenceTimer = null;\n      if \(!_active \|\| _intentionalStop \|\| !_usingBrowser \|\| !_segmentHasSpeech\) \{\n        return;\n      \}\n      _onSilence\?\.call\(\);\n    \}\);\n  \}'''

new_arm = '''  void _armSilence() {
    _silenceTimer?.cancel();
    if (!_active || _intentionalStop) return;
    _silenceTimer = Timer(silenceBeforeCountdown, () {
      _silenceTimer = null;
      if (!_active || _intentionalStop) return;
      if (_usingBrowser) {
        _onSilence?.call();
      } else {
        unawaited(_finalizeSegment(
          restart: true,
          triggerSilence: true,
          forceTranscribe: false,
        ));
      }
    });
  }'''
code = re.sub(old_arm, new_arm, code, flags=re.DOTALL)

with open('lib/src/features/ai/presentation/services/live_voice_input.dart', 'w') as f:
    f.write(code)
