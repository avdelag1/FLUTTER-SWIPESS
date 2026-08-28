from pathlib import Path

path = Path('lib/src/features/profile/presentation/screens/edit_profile_screen.dart')
text = path.read_text()
needle = "import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';\n"
addition = needle + "import 'package:flutter_swipes/src/core/routing/app_paths.dart';\n"
if text.count(needle) != 1:
    raise SystemExit(f'expected one chrome provider import, found {text.count(needle)}')
if "core/routing/app_paths.dart" not in text:
    text = text.replace(needle, addition, 1)
path.write_text(text)

for temporary in (
    '.github/patch_missing_apppaths_import.py',
    '.github/workflows/one-shot-profile-routing-compile.yml',
):
    p = Path(temporary)
    if p.exists():
        p.unlink()
