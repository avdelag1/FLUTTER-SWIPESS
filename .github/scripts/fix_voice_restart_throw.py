from pathlib import Path

path = Path('lib/src/features/ai/presentation/services/live_voice_input.dart')
src = path.read_text()
old = """      try {
        await _startNativeListen();
      } catch (_) {
        if (_active && !_intentionalStop) {
          _onError?.call(
            'Voice recognition could not restart. Tap the microphone to try again.',
          );
        }
      }
"""
new = """      try {
        await _startNativeListen();
      } catch (_) {
        if (!_active || _intentionalStop) return;
        if (_nativeTransientFailures < 4) {
          _nativeTransientFailures += 1;
          _finishNativeSegmentAndRestart(
            restartDelay: const Duration(milliseconds: 650),
          );
          return;
        }
        _onError?.call(
          'Voice recognition could not restart. Tap the microphone to try again.',
        );
      }
"""
count = src.count(old)
if count != 1:
    raise SystemExit(f'voice restart catch expected 1 match, got {count}')
src = src.replace(old, new, 1)
path.write_text(src)
assert '_nativeTransientFailures < 4' in src
