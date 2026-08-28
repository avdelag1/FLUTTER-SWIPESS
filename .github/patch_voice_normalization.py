from pathlib import Path

path = Path('lib/src/core/widgets/glow_search_bar.dart')
text = path.read_text()

for unsafe in (
    "      ('context', 'contact'),\n",
    "      ('contacts info', 'contact'),\n",
    "      ('con tact', 'contact'),\n",
):
    if text.count(unsafe) != 1:
        raise SystemExit(f'expected one unsafe voice replacement: {unsafe.strip()}')
    text = text.replace(unsafe, '', 1)

path.write_text(text)

for temporary in (
    '.github/patch_voice_normalization.py',
    '.github/workflows/one-shot-safe-voice-normalization.yml',
):
    p = Path(temporary)
    if p.exists():
        p.unlink()
