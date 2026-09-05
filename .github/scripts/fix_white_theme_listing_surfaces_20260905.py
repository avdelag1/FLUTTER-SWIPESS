from pathlib import Path


def patch(path: str, replacements: list[tuple[str, str]]) -> None:
    p = Path(path)
    text = p.read_text()
    original = text
    for old, new in replacements:
        if old in text:
            text = text.replace(old, new)
    if text != original:
        p.write_text(text)
        print(f'patched {path}')
    else:
        print(f'no changes needed {path}')


# AI listing uploader: every non-media surface must follow light/dark theme.
ai = 'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart'
patch(ai, [
    ("color: const Color(0xFFD8D8DE),\n                fontSize: 9,", "color: _muted,\n                fontSize: 9,"),
    ("color: const Color(0xFFF1F1F5),\n                      fontSize: 9.5,", "color: _ink,\n                      fontSize: 9.5,"),
    ("border: Border.all(color: Colors.white.withValues(alpha: .08)),\n        ),\n        child: Column(", "border: Border.all(color: _hairline),\n        ),\n        child: Column("),
    ("color: Colors.white.withValues(alpha: .20),\n                  borderRadius", "color: _isLight\n                      ? Colors.black.withValues(alpha: .18)\n                      : Colors.white.withValues(alpha: .20),\n                  borderRadius"),
    ("color: Color(0xFF8F8F98),\n          size: 18,", "color: _muted,\n          size: 18,"),
    ("color: const Color(0xFF777780),\n                          fontSize: 8.5,", "color: _faint,\n                          fontSize: 8.5,"),
    ("foregroundColor: const Color(0xFFD8D8DE),\n                        backgroundColor: Colors.white.withValues(alpha: .055),", "foregroundColor: _ink,\n                        backgroundColor: _isLight\n                            ? const Color(0xFFF2F2F5)\n                            : Colors.white.withValues(alpha: .055),"),
    ("color: Colors.white.withValues(alpha: .08),\n                          ),", "color: _hairline,\n                          ),"),
    ("color: const Color(0xFF8F8F98),\n                        fontSize: 10,", "color: _muted,\n                        fontSize: 10,"),
    ("backgroundColor: Colors.white.withValues(alpha: .07),\n                    foregroundColor: Colors.white,\n                    elevation: 0,", "backgroundColor: _isLight\n                        ? const Color(0xFFF1F1F4)\n                        : Colors.white.withValues(alpha: .07),\n                    foregroundColor: _ink,\n                    elevation: 0,"),
    ("color: Colors.white.withValues(alpha: .045),\n                  borderRadius: BorderRadius.circular(12),", "color: _panelRaisedColor,\n                  borderRadius: BorderRadius.circular(12),\n                  border: Border.all(color: _hairline),"),
    ("color: const Color(0xFF9B9BA5),\n                      size: 17,", "color: _muted,\n                      size: 17,"),
    ("color: const Color(0xFF8F8F98),\n                fontSize: 9.5,", "color: _muted,\n                fontSize: 9.5,"),
    ("color: const Color(0xFF8F8F98),\n            fontSize: 9.5,", "color: _muted,\n            fontSize: 9.5,"),
    ("color: const Color(0xFF8F8F98),\n                fontSize: 8.5,", "color: _faint,\n                fontSize: 8.5,"),
    ("color: selected ? _pink : _panelRaised,", "color: selected ? _pink : _panelRaisedColor,"),
    ("color: selected ? _pink : Colors.white.withValues(alpha: .07),", "color: selected ? _pink : _hairline,"),
    ("Icon(icon, color: Colors.white, size: 18),", "Icon(icon, color: selected ? Colors.white : _ink, size: 18),"),
    ("color: Colors.white,\n                fontSize: 10.5,\n                fontWeight: FontWeight.w900,", "color: selected ? Colors.white : _ink,\n                fontSize: 10.5,\n                fontWeight: FontWeight.w900,"),
    ("color: _micWanted\n            ? _pink.withValues(alpha: .16)\n            : Colors.white.withValues(alpha: .055),", "color: _micWanted\n            ? _pink.withValues(alpha: .16)\n            : _panelRaisedColor,"),
    ("color: _micWanted ? _pink : const Color(0xFF8F8F98),", "color: _micWanted ? _pink : _muted,"),
    ("backgroundColor: _micWanted ? _pink : Colors.white,\n          foregroundColor: _micWanted ? Colors.white : Colors.black,", "backgroundColor: _micWanted ? _pink : _panelRaisedColor,\n          foregroundColor: _micWanted ? Colors.white : _ink,"),
    ("shape: const CircleBorder(),", "shape: CircleBorder(side: BorderSide(color: _micWanted ? _pink : _hairline)),"),
    ("gradient: const LinearGradient(\n          begin: Alignment.topLeft,\n          end: Alignment.bottomRight,\n          colors: [Color(0xFF222228), Color(0xFF17171C)],\n        ),\n        borderRadius: BorderRadius.circular(20),\n        boxShadow: [\n          BoxShadow(\n            color: Colors.black.withValues(alpha: .30),", "gradient: LinearGradient(\n          begin: Alignment.topLeft,\n          end: Alignment.bottomRight,\n          colors: _lightAwareGradient,\n        ),\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: _hairline),\n        boxShadow: [\n          BoxShadow(\n            color: Colors.black.withValues(alpha: _isLight ? .07 : .30),"),
    ("color: Colors.white.withAlpha(8),\n                        borderRadius: BorderRadius.circular(12),\n                      ),\n                      child: Icon(Icons.add_rounded, color: Colors.white),", "color: _panelRaisedColor,\n                        borderRadius: BorderRadius.circular(12),\n                        border: Border.all(color: _hairline),\n                      ),\n                      child: Icon(Icons.add_rounded, color: _ink),"),
])

# Manual listing wizard: cards, modals, mode labels and media metadata must be
# legible on white canvas while keeping actual video/photo overlays unchanged.
manual = 'lib/src/features/add/presentation/screens/add_listing_screen.dart'
patch(manual, [
    ("? const Color(0x2610B981)\n                      : Colors.white.withAlpha(10),", "? const Color(0x2610B981)\n                      : MatteSurface.elevated(context),"),
    ("? const Color(0x4D10B981)\n                        : Colors.white.withAlpha(20),", "? const Color(0x4D10B981)\n                        : MatteSurface.hairline(context),"),
    ("color: const Color(0xFF17171C),\n              borderRadius: BorderRadius.circular(26),\n              border: Border.all(color: Colors.white.withAlpha(20)),", "color: MatteSurface.cardFill(context),\n              borderRadius: BorderRadius.circular(26),\n              border: Border.all(color: MatteSurface.hairline(context)),"),
    ("color: Colors.white.withAlpha(9),\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: Colors.white.withAlpha(22)),", "color: MatteSurface.cardFill(context),\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: MatteSurface.hairline(context)),"),
    ("color: Colors.white.withAlpha(8),\n                  borderRadius: BorderRadius.circular(12),", "color: MatteSurface.elevated(context),\n                  borderRadius: BorderRadius.circular(12),\n                  border: Border.all(color: MatteSurface.hairline(context)),"),
    ("color: const Color(0xB3FFFFFF),\n            fontWeight: FontWeight.w800,\n            fontSize: 11,", "color: MatteSurface.muted(context),\n            fontWeight: FontWeight.w800,\n            fontSize: 11,"),
    ("color: Colors.white.withAlpha(8),\n              borderRadius: BorderRadius.circular(18),\n              border: Border.all(color: Colors.white.withAlpha(20)),", "color: MatteSurface.cardFill(context),\n              borderRadius: BorderRadius.circular(18),\n              border: Border.all(color: MatteSurface.hairline(context)),"),
    ("color: draft.videoAudioEnabled\n                        ? Colors.white\n                        : AppTheme.brandPrimary,", "color: draft.videoAudioEnabled\n                        ? MatteSurface.ink(context)\n                        : AppTheme.brandPrimary,"),
    ("color: Colors.white.withAlpha(8),\n                      borderRadius: BorderRadius.circular(18),\n                      border: Border.all(color: MatteSurface.hairline(context)),", "color: MatteSurface.elevated(context),\n                      borderRadius: BorderRadius.circular(18),\n                      border: Border.all(color: MatteSurface.hairline(context)),"),
    ("color: Colors.white.withAlpha(9),\n          borderRadius: BorderRadius.circular(18),\n          border: Border.all(color: Colors.white.withAlpha(22)),", "color: MatteSurface.cardFill(context),\n          borderRadius: BorderRadius.circular(18),\n          border: Border.all(color: MatteSurface.hairline(context)),"),
])

# Shared dropdown sheets are used throughout listing details.
dropdown = 'lib/src/core/widgets/glass_dropdown_field.dart'
patch(dropdown, [
    ("color: Colors.white.withOpacity(0.2),", "color: MatteSurface.hairline(context),"),
    ("color: const Color(0xB3FFFFFF),\n                        fontWeight: FontWeight.w800,", "color: MatteSurface.muted(context),\n                        fontWeight: FontWeight.w800,"),
    ("color: Colors.white.withOpacity(0.05),", "color: MatteSurface.hairline(context),"),
    ("? AppTheme.brandPrimary\n                                          : Colors.white,", "? AppTheme.brandPrimary\n                                          : MatteSurface.ink(context),"),
])

# Chip selectors make up most of the category-specific listing fields.
chips = 'lib/src/core/widgets/chip_selector.dart'
p = Path(chips)
text = p.read_text()
if "import 'package:flutter_swipes/src/core/theme/matte_surface.dart';" not in text:
    text = text.replace(
        "import 'package:flutter_swipes/src/core/theme/app_theme.dart';\n",
        "import 'package:flutter_swipes/src/core/theme/app_theme.dart';\nimport 'package:flutter_swipes/src/core/theme/matte_surface.dart';\n",
    )
p.write_text(text)
patch(chips, [
    ("color: const Color(0xB3FFFFFF),\n              fontWeight: FontWeight.w800,", "color: MatteSurface.muted(context),\n              fontWeight: FontWeight.w800,"),
    ("? AppTheme.brandPrimary.withAlpha(22)\n                : Colors.white.withAlpha(7),", "? AppTheme.brandPrimary.withAlpha(22)\n                : MatteSurface.elevated(context),"),
    ("? AppTheme.brandPrimary.withAlpha(150)\n                  : Colors.white.withAlpha(30),", "? AppTheme.brandPrimary.withAlpha(150)\n                  : MatteSurface.hairline(context),"),
    ("color: Colors.white,\n                        fontSize: 10.5,", "color: MatteSurface.ink(context),\n                        fontSize: 10.5,"),
    ("? Colors.white54\n                            : AppTheme.brandPrimary,", "? MatteSurface.faint(context)\n                            : AppTheme.brandPrimary,"),
    ("child: const Icon(\n                  Icons.keyboard_arrow_down_rounded,\n                  color: Colors.white70,\n                  size: 23,\n                ),", "child: Icon(\n                  Icons.keyboard_arrow_down_rounded,\n                  color: MatteSurface.muted(context),\n                  size: 23,\n                ),"),
    ("color: active ? AppTheme.brandPrimary : Colors.white,\n            width: 1.5,", "color: active\n                ? AppTheme.brandPrimary\n                : MatteSurface.hairline(context),\n            width: 1.5,"),
    ("color: Colors.white,\n            fontWeight: FontWeight.w700,\n            fontSize: 12,", "color: active ? Colors.white : MatteSurface.ink(context),\n            fontWeight: FontWeight.w700,\n            fontSize: 12,"),
])

# Guard the important theme conversions so CI fails if a later edit reverts them.
checks = {
    ai: [
        'color: selected ? _pink : _panelRaisedColor',
        'backgroundColor: _micWanted ? _pink : _panelRaisedColor',
        'colors: _lightAwareGradient',
        'child: Icon(Icons.add_rounded, color: _ink)',
    ],
    manual: [
        'color: MatteSurface.cardFill(context)',
        'color: MatteSurface.elevated(context)',
        'color: MatteSurface.muted(context)',
    ],
    dropdown: [
        'color: MatteSurface.muted(context)',
        ': MatteSurface.ink(context)',
    ],
    chips: [
        "import 'package:flutter_swipes/src/core/theme/matte_surface.dart';",
        'MatteSurface.elevated(context)',
        'MatteSurface.ink(context)',
    ],
}
for path, needles in checks.items():
    body = Path(path).read_text()
    missing = [needle for needle in needles if needle not in body]
    if missing:
        raise SystemExit(f'{path}: missing theme conversions: {missing}')

print('listing white-theme repair complete')
