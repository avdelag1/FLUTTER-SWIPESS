from pathlib import Path

path = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
text = path.read_text()

# The old independent random timers were removed by the sequential media patch,
# so these imports and delay/stagger plumbing are now dead code.
text = text.replace("import 'dart:async';\nimport 'dart:math' as math;\n\n", '')
text = text.replace('          stagger: Duration(seconds: int.parse(item.delaySeconds)),\n', '')
text = text.replace('    required this.stagger,\n', '')
text = text.replace('  final Duration stagger;\n', '')
text = text.replace('    required this.delaySeconds,\n', '')
text = text.replace('  final String delaySeconds;\n', '')

for value in ('0','4','8','12','16','20','24','28','32','36','40','44'):
    text = text.replace(f"    delaySeconds: '{value}',\n", '')

path.write_text(text)
print('Removed obsolete dashboard timer plumbing.')
