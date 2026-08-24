import re

with open('lib/src/features/ai/presentation/services/live_voice_input.dart', 'r') as f:
    code = f.read()

# Add _segmentHasSpeech = true inside onText
old_on_text = r'''          onText: \(speech, isFinal\) \{\n            if \(!_active \|\| !_usingBrowser \|\| _intentionalStop\) return;\n            final clean = speech\.trim\(\);\n            if \(clean\.isEmpty\) return;\n\n            final total = _join\(_committed, clean\);\n            if \(total != _lastPublished\) \{\n              _lastPublished = total;\n              _onText\?\.call\(total\);\n            \}\n            // Browser silence is based on the last transcript update, not raw\n            // room amplitude. Background noise can no longer reset this forever.\n            _armBrowserSilence\(\);\n          \},'''

new_on_text = '''          onText: (speech, isFinal) {
            if (!_active || !_usingBrowser || _intentionalStop) return;
            final clean = speech.trim();
            if (clean.isEmpty) return;
            
            _segmentHasSpeech = true;

            final total = _join(_committed, clean);
            if (total != _lastPublished) {
              _lastPublished = total;
              _onText?.call(total);
            }
            // Browser silence is based on the last transcript update, not raw
            // room amplitude. Background noise can no longer reset this forever.
            _armBrowserSilence();
          },'''

code = code.replace(old_on_text, new_on_text)

# Let's also lower the webSpeechGateDb from -34.0 to -45.0 just in case.
code = code.replace('static const double _webSpeechGateDb = -34.0;', 'static const double _webSpeechGateDb = -45.0;')

with open('lib/src/features/ai/presentation/services/live_voice_input.dart', 'w') as f:
    f.write(code)
