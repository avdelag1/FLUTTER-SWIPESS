import re

with open('lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart', 'r') as f:
    code = f.read()

# Replace graphic_eq_rounded with mic_rounded (or stop_rounded). The user doesn't want waveform.
# If they are recording, they should just see a glowing mic, or a stop button.
# In ai_search_bar, we used `Icons.mic_rounded` inside a BreathingWidget.
# Here we can just change graphic_eq_rounded to mic_rounded or stop_rounded.
code = code.replace('Icons.graphic_eq_rounded', 'Icons.mic_rounded')
code = code.replace('Icons.mic_none_rounded', 'Icons.mic_rounded')

with open('lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart', 'w') as f:
    f.write(code)
