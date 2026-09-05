from pathlib import Path

ROOT = Path('.')


def read(path: str) -> str:
    return (ROOT / path).read_text()


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'anchor missing: {label}')
    return text.replace(old, new, 1)

p = 'lib/src/features/studio/presentation/screens/studio_composer_screen.dart'
s = read(p)

old = """    _photoFits = Map<int, StudioPhotoFit>.of(\n      initial?.photoFits ?? const <int, StudioPhotoFit>{},\n    );\n"""
new = """    // Studio is portrait-first. Persist an explicit 9:16 framing choice for\n    // every selected photo instead of relying only on a downstream fallback.\n    // Existing projects keep deliberate FIT choices; new/unset photos are\n    // always PORTRAIT.\n    _photoFits = <int, StudioPhotoFit>{\n      for (var i = 0; i < _photos.length; i++)\n        i: initial?.photoFits[i] ?? StudioPhotoFit.portrait,\n    };\n"""
s = replace_once(s, old, new, 'explicit portrait defaults')

old = """  void _setPhotoFit(StudioPhotoFit fit) {\n    setState(() {\n      _renderedVideo = null;\n      _realVideoError = null;\n      _photoFits[_selectedPhoto] = fit;\n      _playing = true;\n    });\n  }\n\n"""
new = old + """  void _setAllPhotosPortrait() {\n    setState(() {\n      _renderedVideo = null;\n      _realVideoError = null;\n      _photoFits = <int, StudioPhotoFit>{\n        for (var i = 0; i < _photos.length; i++) i: StudioPhotoFit.portrait,\n      };\n      _playing = true;\n    });\n  }\n\n"""
s = replace_once(s, old, new, 'portrait all action')

anchor = """          Wrap(\n            spacing: 8,\n            runSpacing: 8,\n            children: [\n              ChoiceChip(\n                selected: portrait,\n"""
if anchor not in s:
    raise SystemExit('anchor missing: framing chips')

old_after = """              ),\n            ],\n          ),\n          const SizedBox(height: 8),\n          Text(\n            portrait\n"""
new_after = """              ),\n            ],\n          ),\n          const SizedBox(height: 7),\n          Align(\n            alignment: Alignment.centerLeft,\n            child: TextButton.icon(\n              onPressed: _photos.isEmpty ? null : _setAllPhotosPortrait,\n              style: TextButton.styleFrom(\n                foregroundColor: Colors.white,\n                visualDensity: VisualDensity.compact,\n                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),\n              ),\n              icon: const Icon(Icons.crop_portrait_rounded, size: 17),\n              label: Text(\n                'PORTRAIT ALL',\n                style: GoogleFonts.plusJakartaSans(\n                  fontSize: 9.5,\n                  fontWeight: FontWeight.w900,\n                  letterSpacing: .35,\n                ),\n              ),\n            ),\n          ),\n          const SizedBox(height: 4),\n          Text(\n            portrait\n"""
s = replace_once(s, old_after, new_after, 'portrait all button')
write(p, s)

p = 'test/studio_portrait_all_guard_test.dart'
write(
    p,
    """import 'dart:io';\n\nimport 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('Studio explicitly defaults every unset photo to portrait', () {\n    final source = File(\n      'lib/src/features/studio/presentation/screens/studio_composer_screen.dart',\n    ).readAsStringSync();\n\n    expect(\n      source,\n      contains('i: initial?.photoFits[i] ?? StudioPhotoFit.portrait'),\n    );\n    expect(source, contains('void _setAllPhotosPortrait()'));\n    expect(source, contains("'PORTRAIT ALL'"));\n  });\n}\n""",
)
