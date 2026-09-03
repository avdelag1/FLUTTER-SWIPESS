from pathlib import Path

path = Path('lib/src/features/profile/presentation/screens/social_boost_screen.dart')
text = path.read_text()
old = 'MatteSurface.border(context)'
count = text.count(old)
if count != 3:
    raise SystemExit(f'expected 3 Social Boost border helpers, found {count}')
path.write_text(text.replace(old, 'MatteSurface.hairline(context)'))
print('patched Social Boost matte hairlines')
# trigger v2
