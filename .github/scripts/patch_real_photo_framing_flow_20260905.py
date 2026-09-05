from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing pattern: {label}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Manual listing flow
# ---------------------------------------------------------------------------
manual_path = Path('lib/src/features/add/presentation/screens/add_listing_screen.dart')
manual = manual_path.read_text()

manual = replace_once(
    manual,
    "import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';\n",
    "import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';\n"
    "import 'package:flutter_swipes/src/features/add/presentation/screens/listing_photo_framing_screen.dart';\n",
    'manual framing import',
)

anchor = """class _PhotosStep extends ConsumerWidget {
  const _PhotosStep({required this.draft});
  final ListingDraft draft;

  Future<void> _pickVideo(BuildContext context, WidgetRef ref) async {
"""
replacement = """class _PhotosStep extends ConsumerWidget {
  const _PhotosStep({required this.draft});
  final ListingDraft draft;

  Future<List<XFile>> _framePickedPhotos(
    BuildContext context,
    List<XFile> picked, {
    String title = 'PHOTO FRAMING',
  }) async {
    if (picked.isEmpty || !context.mounted) return const <XFile>[];
    final framed = await Navigator.of(context, rootNavigator: true)
        .push<List<XFile>>(
          MaterialPageRoute(
            builder: (_) => ListingPhotoFramingScreen(
              photos: List<XFile>.unmodifiable(picked),
              title: title,
            ),
          ),
        );
    return framed ?? const <XFile>[];
  }

  Future<void> _pickFramedPhotos(BuildContext context, WidgetRef ref) async {
    final current = ref.read(addListingProvider);
    final remaining = current.maxPhotos - current.photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum photos reached for this listing.')),
      );
      return;
    }

    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 93,
        maxWidth: 2880,
        maxHeight: 2880,
        requestFullMetadata: false,
      );
      picked = file == null ? const <XFile>[] : <XFile>[file];
    } else {
      picked = await picker.pickMultiImage(
        limit: remaining,
        imageQuality: 93,
        maxWidth: 2880,
        maxHeight: 2880,
        requestFullMetadata: false,
      );
    }
    if (picked.isEmpty || !context.mounted) return;

    final studio = ref.read(studioListingSelectionProvider);
    final framed = await _framePickedPhotos(
      context,
      picked.take(remaining).toList(growable: false),
      title: studio?.hasRenderedVideo == true
          ? 'FRAME PHOTOS AFTER VIDEO'
          : 'PHOTO FRAMING',
    );
    if (framed.isEmpty || !context.mounted) return;
    ref.read(addListingProvider.notifier).update(
      (d) => d.copyWith(
        photos: <XFile>[...d.photos, ...framed]
            .take(d.maxPhotos)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _pickVideo(BuildContext context, WidgetRef ref) async {
"""
manual = replace_once(manual, anchor, replacement, 'manual framing helpers')

old = """              onCreateRealVideo: (studioResult, {onProgress}) async {
                final nextPhotos = <XFile>[
                  ...studioResult.photos,
                  ...draft.photos.skip(6),
                ];
                final notifier = ref.read(addListingProvider.notifier);
"""
new = """              onCreateRealVideo: (studioResult, {onProgress}) async {
                onProgress?.call('Creating real 9:16 listing photos...');
                final framedStudioPhotos = await bakeListingPhotoFrames(
                  studioResult.photos,
                  photoFits: studioResult.project.photoFits,
                  focalPoints: studioResult.project.focalPoints,
                );
                final nextPhotos = <XFile>[
                  ...framedStudioPhotos,
                  ...draft.photos.skip(6),
                ];
                final notifier = ref.read(addListingProvider.notifier);
"""
manual = replace_once(manual, old, new, 'manual Studio bakes gallery photos')

old = """    if (result == null || !context.mounted) return;
    final nextPhotos = <XFile>[...result.photos, ...draft.photos.skip(6)];
    final rendered = ref.read(studioListingSelectionProvider);
"""
new = """    if (result == null || !context.mounted) return;
    // onCreateRealVideo already replaced the first Studio sources with their
    // real 9:16 gallery files. Never overwrite them with the raw originals
    // returned by the composer after the MP4 is confirmed.
    final nextPhotos = List<XFile>.of(ref.read(addListingProvider).photos);
    final rendered = ref.read(studioListingSelectionProvider);
"""
manual = replace_once(manual, old, new, 'manual keep baked Studio photos')

manual = replace_once(
    manual,
    """                onTap: () => ref.read(addListingProvider.notifier).pickPhotos(),
""",
    """                onTap: () => _pickFramedPhotos(context, ref),
""",
    'manual top Photos button',
)
manual = replace_once(
    manual,
    """                  onTap: () =>
                      ref.read(addListingProvider.notifier).pickPhotos(),
""",
    """                  onTap: () => _pickFramedPhotos(context, ref),
""",
    'manual grid add button',
)

old = """            final picked = files.whereType<XFile>().toList();
            if (picked.isEmpty) return;
            ref
                .read(addListingProvider.notifier)
                .update(
                  (d) => d.copyWith(
                    photos: [...d.photos, ...picked].take(d.maxPhotos).toList(),
                  ),
                );
"""
new = """            final picked = files.whereType<XFile>().toList();
            if (picked.isEmpty) return;
            final framed = await _framePickedPhotos(
              context,
              picked,
              title: 'FRAME CAMERA PHOTOS',
            );
            if (framed.isEmpty || !context.mounted) return;
            ref
                .read(addListingProvider.notifier)
                .update(
                  (d) => d.copyWith(
                    photos: [...d.photos, ...framed]
                        .take(d.maxPhotos)
                        .toList(growable: false),
                  ),
                );
"""
manual = replace_once(manual, old, new, 'manual camera framing')

manual_path.write_text(manual)


# ---------------------------------------------------------------------------
# AI listing flow
# ---------------------------------------------------------------------------
ai_path = Path('lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart')
ai = ai_path.read_text()

ai = replace_once(
    ai,
    "import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';\n",
    "import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';\n"
    "import 'package:flutter_swipes/src/features/add/presentation/screens/listing_photo_framing_screen.dart';\n",
    'AI framing import',
)

old = """    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked.take(remaining)));
  }

  Future<void> _openStudio() async {
"""
new = """    if (picked.isEmpty || !mounted) return;
    final studio = ref.read(studioListingSelectionProvider);
    final framed = await Navigator.of(context, rootNavigator: true)
        .push<List<XFile>>(
          MaterialPageRoute(
            builder: (_) => ListingPhotoFramingScreen(
              photos: picked.take(remaining).toList(growable: false),
              title: studio?.hasRenderedVideo == true
                  ? 'FRAME PHOTOS AFTER VIDEO'
                  : 'PHOTO FRAMING',
            ),
          ),
        );
    if (framed == null || framed.isEmpty || !mounted) return;
    setState(() => _photos.addAll(framed));
  }

  Future<void> _openStudio() async {
"""
ai = replace_once(ai, old, new, 'AI pick framing screen')

old = """              onCreateRealVideo: (studioResult, {onProgress}) async {
                final nextPhotos = <XFile>[
                  ...studioResult.photos,
                  ..._photos.skip(6),
                ];
                final notifier = ref.read(addListingProvider.notifier);
"""
new = """              onCreateRealVideo: (studioResult, {onProgress}) async {
                onProgress?.call('Creating real 9:16 listing photos...');
                final framedStudioPhotos = await bakeListingPhotoFrames(
                  studioResult.photos,
                  photoFits: studioResult.project.photoFits,
                  focalPoints: studioResult.project.focalPoints,
                );
                final nextPhotos = <XFile>[
                  ...framedStudioPhotos,
                  ..._photos.skip(6),
                ];
                final notifier = ref.read(addListingProvider.notifier);
"""
ai = replace_once(ai, old, new, 'AI Studio bakes gallery photos')

old = """    if (result == null || !mounted) return;
    final nextPhotos = <XFile>[...result.photos, ..._photos.skip(6)];
    final rendered = ref.read(studioListingSelectionProvider);
"""
new = """    if (result == null || !mounted) return;
    // The renderer callback already replaced Studio's raw sources with the
    // baked 9:16 gallery photos. Keep those exact files after closing Studio.
    final nextPhotos = List<XFile>.of(ref.read(addListingProvider).photos);
    final rendered = ref.read(studioListingSelectionProvider);
"""
ai = replace_once(ai, old, new, 'AI keep baked Studio photos')

ai_path.write_text(ai)

# ---------------------------------------------------------------------------
# Guard the intended flow.
# ---------------------------------------------------------------------------
manual = manual_path.read_text()
ai = ai_path.read_text()
assert "ListingPhotoFramingScreen" in manual
assert "ListingPhotoFramingScreen" in ai
assert "bakeListingPhotoFrames(" in manual
assert "bakeListingPhotoFrames(" in ai
assert "FRAME PHOTOS AFTER VIDEO" in manual
assert "FRAME PHOTOS AFTER VIDEO" in ai
assert "pickPhotos()" not in manual[manual.index('class _PhotosStep'):manual.index('class _MediaPickCard')]
print('real portrait/FIT listing photo flow patched')
