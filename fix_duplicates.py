import re

with open('lib/src/features/ai/presentation/services/live_voice_input.dart', 'r') as f:
    code = f.read()

# Fix declarations
code = code.replace('  Timer? _silenceTimer;\n  Timer? _silenceTimer;', '  Timer? _silenceTimer;')

# Fix cancel()
code = code.replace('    _silenceTimer?.cancel();\n    _silenceTimer?.cancel();', '    _silenceTimer?.cancel();')

# Fix null
code = code.replace('    _silenceTimer = null;\n    _silenceTimer = null;', '    _silenceTimer = null;')

with open('lib/src/features/ai/presentation/services/live_voice_input.dart', 'w') as f:
    f.write(code)
