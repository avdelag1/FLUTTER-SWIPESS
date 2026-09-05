from pathlib import Path
import re

MANUAL = Path('lib/src/features/add/presentation/screens/add_listing_screen.dart')
AI = Path('lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart')


def must_replace(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch target: {label}')
    return text.replace(old, new, 1)

# MANUAL LISTING
s = MANUAL.read_text()
s = s.replace("import 'package:flutter_swipes/src/features/add/presentation/screens/listing_photo_framing_screen.dart';\n", '')

s, count = re.subn(
    r"\n  Future<List<XFile>> _framePickedPhotos\(.*?\n  Future<void> _pickFramedPhotos",
    "\n  Future<void> _pickFramedPhotos",
    s,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit('manual: could not remove framing helper')

old = '''    final studio = ref.read(studioListingSelectionProvider);\n    final framed = await _framePickedPhotos(\n      context,\n      picked.take(remaining).toList(growable: false),\n      title: studio?.hasRenderedVideo == true\n          ? 'FRAME PHOTOS AFTER VIDEO'\n          : 'PHOTO FRAMING',\n    );\n    if (framed.isEmpty || !context.mounted) return;\n    ref.read(addListingProvider.notifier).update(\n      (d) => d.copyWith(\n        photos: <XFile>[...d.photos, ...framed]\n            .take(d.maxPhotos)\n            .toList(growable: false),\n      ),\n    );\n'''
new = '''    final accepted = picked.take(remaining).toList(growable: false);\n    if (accepted.isEmpty || !context.mounted) return;\n    // Keep the original HQ photo untouched. Portrait is a display concern:\n    // swipe cards and quick filters render listing photos with BoxFit.cover.\n    ref.read(addListingProvider.notifier).update(\n      (d) => d.copyWith(\n        photos: <XFile>[...d.photos, ...accepted]\n            .take(d.maxPhotos)\n            .toList(growable: false),\n      ),\n    );\n'''
s = must_replace(s, old, new, 'manual raw gallery picker')

old = '''            final framed = await _framePickedPhotos(\n              context,\n              picked,\n              title: 'FRAME CAMERA PHOTOS',\n            );\n            if (framed.isEmpty || !context.mounted) return;\n            ref\n                .read(addListingProvider.notifier)\n                .update(\n                  (d) => d.copyWith(\n                    photos: [...d.photos, ...framed]\n                        .take(d.maxPhotos)\n                        .toList(growable: false),\n                  ),\n                );\n'''
new = '''            if (!context.mounted) return;\n            // Camera photos also stay as original HQ files. The portrait card\n            // crops only at render time, never destructively at upload time.\n            ref\n                .read(addListingProvider.notifier)\n                .update(\n                  (d) => d.copyWith(\n                    photos: [...d.photos, ...picked]\n                        .take(d.maxPhotos)\n                        .toList(growable: false),\n                  ),\n                );\n'''
s = must_replace(s, old, new, 'manual raw camera photos')

old = '''              onCreateRealVideo: (studioResult, {onProgress}) async {\n                onProgress?.call('Creating real 9:16 listing photos...');\n                final framedStudioPhotos = await bakeListingPhotoFrames(\n                  studioResult.photos,\n                  photoFits: studioResult.project.photoFits,\n                  focalPoints: studioResult.project.focalPoints,\n                );\n                final nextPhotos = <XFile>[\n                  ...framedStudioPhotos,\n                  ...draft.photos.skip(6),\n                ];\n                final notifier = ref.read(addListingProvider.notifier);\n                notifier.update(\n                  (current) =>\n                      current.copyWith(photos: List<XFile>.of(nextPhotos)),\n                );\n                ref\n                    .read(studioListingSelectionProvider.notifier)\n                    .set(project: studioResult.project, photos: nextPhotos);\n                final ready = await notifier.prepareStudioVideo(\n                  onProgress: onProgress,\n                );\n'''
new = '''              onCreateRealVideo: (studioResult, {onProgress}) async {\n                // Studio may crop/animate the movie, but it must never rewrite\n                // the listing's original photo files.\n                final notifier = ref.read(addListingProvider.notifier);\n                ref\n                    .read(studioListingSelectionProvider.notifier)\n                    .set(project: studioResult.project, photos: studioResult.photos);\n                final ready = await notifier.prepareStudioVideo(\n                  onProgress: onProgress,\n                );\n'''
s = must_replace(s, old, new, 'manual studio raw sources')
s = s.replace('!rendered.matchesPhotos(nextPhotos)) {', '!rendered.matchesPhotos(ref.read(addListingProvider).photos)) {', 1)
s = s.replace(
    '// onCreateRealVideo already replaced the first Studio sources with their\n    // real 9:16 gallery files. Never overwrite them with the raw originals\n    // returned by the composer after the MP4 is confirmed.\n',
    '// Studio only creates the movie. Listing photos remain the untouched HQ\n    // originals and continue after video media #1.\n',
    1,
)
MANUAL.write_text(s)

# AI LISTING
s = AI.read_text()
s = s.replace("import 'package:flutter_swipes/src/features/add/presentation/screens/listing_photo_framing_screen.dart';\n", '')

old = '''    final studio = ref.read(studioListingSelectionProvider);\n    final framed = await Navigator.of(context, rootNavigator: true)\n        .push<List<XFile>>(\n          MaterialPageRoute(\n            builder: (_) => ListingPhotoFramingScreen(\n              photos: picked.take(remaining).toList(growable: false),\n              title: studio?.hasRenderedVideo == true\n                  ? 'FRAME PHOTOS AFTER VIDEO'\n                  : 'PHOTO FRAMING',\n            ),\n          ),\n        );\n    if (framed == null || framed.isEmpty || !mounted) return;\n    setState(() => _photos.addAll(framed));\n'''
new = '''    final accepted = picked.take(remaining).toList(growable: false);\n    if (accepted.isEmpty || !mounted) return;\n    // Preserve original HQ files. Portrait happens only when the app paints\n    // them into the portrait listing/swipe card using BoxFit.cover.\n    setState(() => _photos.addAll(accepted));\n'''
s = must_replace(s, old, new, 'ai raw gallery picker')

old = '''              onCreateRealVideo: (studioResult, {onProgress}) async {\n                onProgress?.call('Creating real 9:16 listing photos...');\n                final framedStudioPhotos = await bakeListingPhotoFrames(\n                  studioResult.photos,\n                  photoFits: studioResult.project.photoFits,\n                  focalPoints: studioResult.project.focalPoints,\n                );\n                final nextPhotos = <XFile>[\n                  ...framedStudioPhotos,\n                  ..._photos.skip(6),\n                ];\n                final notifier = ref.read(addListingProvider.notifier);\n                notifier.update(\n                  (current) =>\n                      current.copyWith(photos: List<XFile>.of(nextPhotos)),\n                );\n                ref\n                    .read(studioListingSelectionProvider.notifier)\n                    .set(project: studioResult.project, photos: nextPhotos);\n                final ready = await notifier.prepareStudioVideo(\n                  onProgress: onProgress,\n                );\n'''
new = '''              onCreateRealVideo: (studioResult, {onProgress}) async {\n                // Keep listing photos untouched. Studio framing applies only\n                // to the generated movie.\n                final notifier = ref.read(addListingProvider.notifier);\n                notifier.update(\n                  (current) =>\n                      current.copyWith(photos: List<XFile>.of(_photos)),\n                );\n                ref\n                    .read(studioListingSelectionProvider.notifier)\n                    .set(project: studioResult.project, photos: studioResult.photos);\n                final ready = await notifier.prepareStudioVideo(\n                  onProgress: onProgress,\n                );\n'''
s = must_replace(s, old, new, 'ai studio raw sources')
s = s.replace('!rendered.matchesPhotos(nextPhotos)) {', '!rendered.matchesPhotos(ref.read(addListingProvider).photos)) {', 1)
s = s.replace(
    '// The renderer callback already replaced Studio\'s raw sources with the\n    // baked 9:16 gallery photos. Keep those exact files after closing Studio.\n',
    '// Studio only creates the movie. Keep the original HQ listing photos.\n',
    1,
)
AI.write_text(s)

print('restored raw listing photo pipeline; portrait stays at display layer')
