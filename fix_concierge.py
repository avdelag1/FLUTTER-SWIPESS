import re

with open('lib/src/features/dashboard/presentation/widgets/concierge_sheet_host.dart', 'r') as f:
    code = f.read()

# Delete the Positioned microphone in concierge_sheet_host.dart
# It starts at:
#                              // One persistent mic visual only. No waveform is
#                              // painted over the composer anymore.
#                              Positioned(

regex = r'                              // One persistent mic visual only\. No waveform is\n                              // painted over the composer anymore\.\n                              Positioned\(.*?child: const Icon\(\n                                                Icons\.mic_rounded,\n                                                color: Colors\.white,\n                                                size: 20,\n                                              \),\n                                            \),\n                                          \);\n                                        \},\n                                      \);\n                                    \},\n                                  \),\n                                \),\n                              \),'

# To be safe and since regex with deep nesting is hard, I will do a substring replacement.
start_idx = code.find('// One persistent mic visual only. No waveform is')
if start_idx != -1:
    end_text = '                              ),'
    end_idx = code.find(end_text, start_idx)
    if end_idx != -1:
        end_idx += len(end_text)
        code = code[:start_idx] + code[end_idx:]

with open('lib/src/features/dashboard/presentation/widgets/concierge_sheet_host.dart', 'w') as f:
    f.write(code)
