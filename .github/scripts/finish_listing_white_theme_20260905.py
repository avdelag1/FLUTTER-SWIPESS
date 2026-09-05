from pathlib import Path


def replace(path: str, old: str, new: str, label: str, *, required: bool = False) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        print(f'already {label}')
        return
    if old not in text:
        if required:
            raise SystemExit(f'{path}: missing pattern for {label}')
        print(f'skip {label}')
        return
    p.write_text(text.replace(old, new))
    print(f'patched {label}')


def ensure_import(path: str, after: str, import_line: str) -> None:
    p = Path(path)
    text = p.read_text()
    if import_line in text:
        return
    if after not in text:
        raise SystemExit(f'{path}: import anchor missing')
    p.write_text(text.replace(after, after + import_line))


# ---------------------------------------------------------------------------
# Edit listing: this route still had hard-coded white text/borders everywhere,
# which made white mode look like an unfinished dark screen.
# ---------------------------------------------------------------------------
edit = 'lib/src/features/add/presentation/screens/edit_listing_screen.dart'
ensure_import(
    edit,
    "import 'package:flutter_swipes/src/core/theme/app_theme.dart';\n",
    "import 'package:flutter_swipes/src/core/theme/matte_surface.dart';\n",
)
repls = [
    ("CircularProgressIndicator(color: Colors.white, strokeWidth: 2)",
     "CircularProgressIndicator(color: AppTheme.brandPrimary, strokeWidth: 2)",
     'edit loading spinner'),
    ("border: Border.all(color: Colors.white, width: 1.5),",
     "border: Border.all(color: MatteSurface.hairline(context), width: 1.5),",
     'edit back border'),
    ("color: Colors.white,\n                          size: 18,",
     "color: MatteSurface.ink(context),\n                          size: 18,",
     'edit back icon'),
    ("color: Colors.white,\n                            fontSize: 11,\n                            fontWeight: FontWeight.w700,",
     "color: MatteSurface.muted(context),\n                            fontSize: 11,\n                            fontWeight: FontWeight.w700,",
     'edit header subtitle'),
    ("Icons.photo_library_rounded,\n                          color: Colors.white,",
     "Icons.photo_library_rounded,\n                          color: MatteSurface.ink(context),",
     'edit gallery icon'),
    ("'Gallery',\n                          style: TextStyle(color: Colors.white),",
     "'Gallery',\n                          style: TextStyle(color: MatteSurface.ink(context)),",
     'edit gallery label'),
    ("Icons.photo_camera_rounded,\n                          color: Colors.white,",
     "Icons.photo_camera_rounded,\n                          color: MatteSurface.ink(context),",
     'edit camera icon'),
    ("'Camera',\n                          style: TextStyle(color: Colors.white),",
     "'Camera',\n                          style: TextStyle(color: MatteSurface.ink(context)),",
     'edit camera label'),
    ("style: GoogleFonts.plusJakartaSans(color: Colors.white),\n                      ),\n                      value: state.furnished,",
     "style: GoogleFonts.plusJakartaSans(\n                          color: MatteSurface.ink(context),\n                        ),\n                      ),\n                      value: state.furnished,",
     'edit furnished label'),
    ("style: GoogleFonts.plusJakartaSans(color: Colors.white),\n                      ),\n                      value: state.petFriendly,",
     "style: GoogleFonts.plusJakartaSans(\n                          color: MatteSurface.ink(context),\n                        ),\n                      ),\n                      value: state.petFriendly,",
     'edit pet label'),
    ("color: Colors.white,\n        fontWeight: FontWeight.w800,\n        fontSize: 11,",
     "color: MatteSurface.muted(context),\n        fontWeight: FontWeight.w800,\n        fontSize: 11,",
     'edit section labels'),
    ("color: Colors.white.withAlpha(8),\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: Colors.white.withAlpha(30)),",
     "color: MatteSurface.cardFill(context),\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: MatteSurface.hairline(context)),",
     'edit video card surface'),
    ("color: Colors.white,\n                          fontSize: 13,\n                          fontWeight: FontWeight.w800,",
     "color: MatteSurface.ink(context),\n                          fontSize: 13,\n                          fontWeight: FontWeight.w800,",
     'edit video title'),
    ("color: Colors.white60,\n                        fontSize: 11,",
     "color: MatteSurface.muted(context),\n                        fontSize: 11,",
     'edit video subtitle'),
    ("foregroundColor: Colors.white,\n                    side: BorderSide(color: Colors.white.withAlpha(54)),",
     "foregroundColor: MatteSurface.ink(context),\n                    side: BorderSide(color: MatteSurface.hairline(context)),",
     'edit replace-video button'),
    ("color: Colors.white,\n                  fontSize: 11,\n                  fontWeight: FontWeight.w800,",
     "color: MatteSurface.ink(context),\n                  fontSize: 11,\n                  fontWeight: FontWeight.w800,",
     'edit video sound title'),
    ("color: Colors.white54,\n                  fontSize: 9.5,",
     "color: MatteSurface.muted(context),\n                  fontSize: 9.5,",
     'edit video sound subtitle'),
    ("color: Colors.white.withAlpha(8),\n                  borderRadius: BorderRadius.circular(12),",
     "color: MatteSurface.elevated(context),\n                  borderRadius: BorderRadius.circular(12),\n                  border: Border.all(color: MatteSurface.hairline(context)),",
     'edit current soundtrack surface'),
    ("color: Colors.white70,\n                      size: 17,",
     "color: MatteSurface.muted(context),\n                      size: 17,",
     'edit current soundtrack icon'),
    ("color: Colors.white,\n                          fontSize: 9.5,\n                          fontWeight: FontWeight.w800,",
     "color: MatteSurface.ink(context),\n                          fontSize: 9.5,\n                          fontWeight: FontWeight.w800,",
     'edit current soundtrack text'),
    ("color: Colors.white38,\n              fontSize: 10,",
     "color: MatteSurface.faint(context),\n              fontSize: 10,",
     'edit video helper text'),
    ("border: Border.all(color: Colors.white24),",
     "border: Border.all(color: MatteSurface.hairline(context)),",
     'edit empty photo border'),
    ("style: GoogleFonts.plusJakartaSans(color: Colors.white),",
     "style: GoogleFonts.plusJakartaSans(color: MatteSurface.ink(context)),",
     'edit empty photo text'),
    ("color: Colors.white38,\n            fontSize: 9.5,",
     "color: MatteSurface.faint(context),\n            fontSize: 9.5,",
     'edit photo reorder helper'),
]
for old, new, label in repls:
    replace(edit, old, new, label)

# The little orange-tinted video-settings tile needs an orange glyph in light
# mode. Keep progress/glyph legible without changing media overlays themselves.
replace(
    edit,
    "child: _preparingVideo\n                    ? Padding(\n                        padding: EdgeInsets.all(12),\n                        child: CircularProgressIndicator(\n                          strokeWidth: 2,\n                          color: Colors.white,\n                        ),\n                      )\n                    : Icon(\n                        Icons.video_settings_rounded,\n                        color: Colors.white,\n                        size: 25,\n                      ),",
    "child: _preparingVideo\n                    ? Padding(\n                        padding: EdgeInsets.all(12),\n                        child: CircularProgressIndicator(\n                          strokeWidth: 2,\n                          color: AppTheme.brandPrimary,\n                        ),\n                      )\n                    : Icon(\n                        Icons.video_settings_rounded,\n                        color: AppTheme.brandPrimary,\n                        size: 25,\n                      ),",
    'edit video-settings glyph',
)

# ---------------------------------------------------------------------------
# Soundtrack picker appears directly inside both AI + manual listing creators.
# It was still a dark card with white labels even when the rest of the page was
# white. Make every nested surface and text state theme-aware.
# ---------------------------------------------------------------------------
sound = 'lib/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart'
ensure_import(
    sound,
    "import 'package:flutter_swipes/src/core/theme/app_theme.dart';\n",
    "import 'package:flutter_swipes/src/core/theme/matte_surface.dart';\n",
)
sound_repls = [
    ("color: Colors.white.withValues(alpha: .035),\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: Colors.white.withValues(alpha: .09)),",
     "color: MatteSurface.well(context),\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: MatteSurface.hairline(context)),",
     'soundtrack outer surface'),
    ("color: Colors.white,\n                    fontSize: 10.5,",
     "color: MatteSurface.ink(context),\n                    fontSize: 10.5,",
     'soundtrack heading'),
    ("foregroundColor: Colors.white,\n                  textStyle:",
     "foregroundColor: MatteSurface.ink(context),\n                  textStyle:",
     'soundtrack upload button'),
    ("color: Colors.white60,\n              fontSize: 9.5,",
     "color: MatteSurface.muted(context),\n              fontSize: 9.5,",
     'soundtrack description'),
    ("? AppTheme.brandPrimary.withValues(alpha: .18)\n                          : Colors.white.withValues(alpha: .045),",
     "? AppTheme.brandPrimary.withValues(alpha: .18)\n                          : MatteSurface.elevated(context),",
     'soundtrack preset surface'),
    ("? AppTheme.brandPrimary\n                            : Colors.white.withValues(alpha: .08),",
     "? AppTheme.brandPrimary\n                            : MatteSurface.hairline(context),",
     'soundtrack preset border'),
    ("? AppTheme.brandPrimary\n                                  : Colors.white54,",
     "? AppTheme.brandPrimary\n                                  : MatteSurface.muted(context),",
     'soundtrack preset icon'),
    ("color: Colors.white,\n                            fontSize: 9.5,\n                            fontWeight: FontWeight.w900,",
     "color: MatteSurface.ink(context),\n                            fontSize: 9.5,\n                            fontWeight: FontWeight.w900,",
     'soundtrack preset title'),
    ("color: Colors.white54,\n                            fontSize: 7.5,",
     "color: MatteSurface.muted(context),\n                            fontSize: 7.5,",
     'soundtrack preset subtitle'),
    ("color: Colors.white,\n                        fontSize: 9.5,\n                        fontWeight: FontWeight.w800,",
     "color: MatteSurface.ink(context),\n                        fontSize: 9.5,\n                        fontWeight: FontWeight.w800,",
     'soundtrack selected text'),
    ("color: Colors.white60,\n                      size: 17,",
     "color: MatteSurface.muted(context),\n                      size: 17,",
     'soundtrack close icon'),
    ("color: Colors.white38,\n              fontSize: 8.5,",
     "color: MatteSurface.faint(context),\n              fontSize: 8.5,",
     'soundtrack legal helper'),
]
for old, new, label in sound_repls:
    replace(sound, old, new, label)

# ---------------------------------------------------------------------------
# Audio trim surface/editor: white theme should remain white around the actual
# video preview. The video itself stays black/immersive by design.
# ---------------------------------------------------------------------------
trim_screen = 'lib/src/features/add/presentation/screens/listing_audio_trim_screen.dart'
ensure_import(
    trim_screen,
    "import 'package:flutter_swipes/src/core/theme/app_theme.dart';\n",
    "import 'package:flutter_swipes/src/core/theme/matte_surface.dart';\n",
)
trim_screen_repls = [
    ("backgroundColor: Colors.black,\n      body: SafeArea(",
     "backgroundColor: MatteSurface.canvas(context),\n      body: SafeArea(",
     'trim screen canvas'),
    ("color: Colors.white,\n                  ),",
     "color: MatteSurface.ink(context),\n                  ),",
     'trim back icon'),
    ("color: Colors.white,\n                            fontSize: 17,",
     "color: MatteSurface.ink(context),\n                            fontSize: 17,",
     'trim title'),
    ("color: Colors.white54,\n                            fontSize: 10,",
     "color: MatteSurface.muted(context),\n                            fontSize: 10,",
     'trim subtitle'),
    ("color: const Color(0xFF17171C),\n                      borderRadius: BorderRadius.circular(20),\n                      border: Border.all(color: Colors.white.withValues(alpha: .07)),",
     "color: MatteSurface.well(context),\n                      borderRadius: BorderRadius.circular(20),\n                      border: Border.all(color: MatteSurface.hairline(context)),",
     'trim audio card'),
    ("color: Colors.white,\n                                  fontSize: 10.5,",
     "color: MatteSurface.ink(context),\n                                  fontSize: 10.5,",
     'trim filename'),
    ("color: Colors.white54,\n                                fontSize: 9,",
     "color: MatteSurface.muted(context),\n                                fontSize: 9,",
     'trim duration'),
    ("painter: _WaveformPainter(snapshot.data),",
     "painter: _WaveformPainter(\n                                  snapshot.data,\n                                  color: MatteSurface.ink(context).withValues(alpha: .78),\n                                ),",
     'trim waveform theme'),
    ("class _WaveformPainter extends CustomPainter {\n  const _WaveformPainter(this.bytes);\n\n  final Uint8List? bytes;",
     "class _WaveformPainter extends CustomPainter {\n  const _WaveformPainter(this.bytes, {required this.color});\n\n  final Uint8List? bytes;\n  final Color color;",
     'trim waveform color field'),
    ("final paint = Paint()\n      ..color = Colors.white.withValues(alpha: .78)",
     "final paint = Paint()\n      ..color = color",
     'trim waveform paint'),
    ("oldDelegate.bytes != bytes;",
     "oldDelegate.bytes != bytes || oldDelegate.color != color;",
     'trim waveform repaint'),
]
for old, new, label in trim_screen_repls:
    replace(trim_screen, old, new, label)

trim_editor = 'lib/src/features/add/presentation/widgets/listing_audio_trim_editor.dart'
ensure_import(
    trim_editor,
    "import 'package:flutter_swipes/src/core/theme/app_theme.dart';\n",
    "import 'package:flutter_swipes/src/core/theme/matte_surface.dart';\n",
)
trim_editor_repls = [
    ("gradient: const LinearGradient(\n          begin: Alignment.topLeft,\n          end: Alignment.bottomRight,\n          colors: [Color(0xFF1E1E24), Color(0xFF131318)],\n        ),\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: Colors.white.withValues(alpha: .08)),",
     "gradient: LinearGradient(\n          begin: Alignment.topLeft,\n          end: Alignment.bottomRight,\n          colors: [\n            MatteSurface.elevated(context),\n            MatteSurface.well(context),\n          ],\n        ),\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: MatteSurface.hairline(context)),",
     'trim editor surface'),
    ("color: Colors.white,\n                    fontSize: 10,",
     "color: MatteSurface.ink(context),\n                    fontSize: 10,",
     'trim editor title'),
    ("color: Colors.white70,\n                  fontSize: 9.5,",
     "color: MatteSurface.muted(context),\n                  fontSize: 9.5,",
     'trim editor selected time'),
    ("color: Colors.white54,\n              fontSize: 9,",
     "color: MatteSurface.muted(context),\n              fontSize: 9,",
     'trim editor instructions'),
    ("foregroundColor: Colors.white,\n                    side: BorderSide(\n                      color: Colors.white.withValues(alpha: .16),\n                    ),",
     "foregroundColor: MatteSurface.ink(context),\n                    side: BorderSide(\n                      color: MatteSurface.hairline(context),\n                    ),",
     'trim editor preview button'),
]
for old, new, label in trim_editor_repls:
    replace(trim_editor, old, new, label)

# ---------------------------------------------------------------------------
# Manual listing photo badges sit on black overlays. Those three glyphs must
# stay white even in light mode (theme ink becomes black and disappeared).
# ---------------------------------------------------------------------------
manual = 'lib/src/features/add/presentation/screens/add_listing_screen.dart'
replace(
    manual,
    "backgroundColor: Colors.black54,\n              child: Icon(\n                Icons.close,\n                size: 14,\n                color: MatteSurface.ink(context),",
    "backgroundColor: Colors.black54,\n              child: Icon(\n                Icons.close,\n                size: 14,\n                color: Colors.white,",
    'manual photo close overlay',
)
replace(
    manual,
    "color: Colors.black54,\n                borderRadius: BorderRadius.circular(8),\n              ),\n              child: Text(\n                'COVER',\n                style: GoogleFonts.plusJakartaSans(\n                  color: MatteSurface.ink(context),",
    "color: Colors.black54,\n                borderRadius: BorderRadius.circular(8),\n              ),\n              child: Text(\n                'COVER',\n                style: GoogleFonts.plusJakartaSans(\n                  color: Colors.white,",
    'manual cover overlay',
)
replace(
    manual,
    "color: Colors.black.withAlpha(150),\n              borderRadius: BorderRadius.circular(8),\n            ),\n            child: Icon(\n              Icons.drag_indicator_rounded,\n              color: MatteSurface.ink(context),",
    "color: Colors.black.withAlpha(150),\n              borderRadius: BorderRadius.circular(8),\n            ),\n            child: Icon(\n              Icons.drag_indicator_rounded,\n              color: Colors.white,",
    'manual drag overlay',
)

# Verify the important tokens are now present. This intentionally checks source
# semantics, while the workflow also compiles every touched surface.
checks = {
    edit: [
        "import 'package:flutter_swipes/src/core/theme/matte_surface.dart';",
        'color: MatteSurface.cardFill(context)',
        'color: MatteSurface.ink(context)',
        'color: MatteSurface.muted(context)',
        'border: Border.all(color: MatteSurface.hairline(context)',
    ],
    sound: [
        'color: MatteSurface.well(context)',
        'color: MatteSurface.elevated(context)',
        'color: MatteSurface.ink(context)',
        'MatteSurface.hairline(context)',
    ],
    trim_screen: [
        'backgroundColor: MatteSurface.canvas(context)',
        'color: MatteSurface.well(context)',
        'required this.color',
    ],
    trim_editor: [
        'MatteSurface.elevated(context)',
        'MatteSurface.well(context)',
        'MatteSurface.ink(context)',
    ],
}
for path, needles in checks.items():
    body = Path(path).read_text()
    missing = [needle for needle in needles if needle not in body]
    if missing:
        raise SystemExit(f'{path}: missing white-theme tokens {missing}')

print('complete listing white-theme pass applied')
