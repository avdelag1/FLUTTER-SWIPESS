import re
with open('lib/src/features/legal/presentation/screens/lawyer_services_screen_v3.dart', 'r') as f:
    text = f.read()

text = re.sub(
r'''Container\(\s*padding:\s*const\s*EdgeInsets\.symmetric\(horizontal:\s*8,\s*vertical:\s*4\),\s*decoration:\s*BoxDecoration\(\s*color:\s*ink\.withAlpha\(8\),\s*borderRadius:\s*BorderRadius\.circular\(999\),\s*border:\s*Border\.all\(color:\s*MatteSurface\.hairline\(context\)\),\s*\),\s*child:\s*Text\(\s*'SOON',\s*style:\s*GoogleFonts\.plusJakartaSans\(\s*color:\s*muted,\s*fontSize:\s*8,\s*fontWeight:\s*FontWeight\.w900,\s*letterSpacing:\s*\.8,\s*\),\s*\),\s*\),''',
'', text)

with open('lib/src/features/legal/presentation/screens/lawyer_services_screen_v3.dart', 'w') as f:
    f.write(text)
