from pathlib import Path

path = Path('.github/patches/listing_media_ai_flow.py')
lines = path.read_text().splitlines()
for i, line in enumerate(lines):
    if line.startswith('end_marker = "                  Row('):
        lines[i] = 'end_marker = "                  Row(\\n                    children: [\\n                      Expanded(child: _sectionTitle(\'DESCRIBE IT\')),\\n"'
        if i + 1 < len(lines) and lines[i + 1] == '"':
            del lines[i + 1]
        break
else:
    raise SystemExit('end_marker assignment not found')
path.write_text('\n'.join(lines) + '\n')
print('fixed listing patch script syntax')
