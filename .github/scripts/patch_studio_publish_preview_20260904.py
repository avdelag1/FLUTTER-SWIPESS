from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f'{label}: already applied')
        return text
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    print(f'{label}: patched')
    return text.replace(old, new, 1)


# AI LISTING BUILDER -----------------------------------------------------------
p = Path('lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart')
s = p.read_text()
s = replace_once(
    s,
    "import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';\n",
    "import 'package:flutter_swipes/src/features/studio/data/cinematic_catalog.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/widgets/cinematic_preview.dart';\n",
    'AI Studio preview imports',
)
s = replace_once(
    s,
    "              child: SizedBox(height: 118, child: _buildVideoPanel()),",
    "              child: SizedBox(height: photoPanelHeight, child: _buildVideoPanel()),",
    'AI video panel follows media height',
)

studio_branch = """    final studioSelection = ref.watch(studioListingSelectionProvider);
    final activeStudio = studioSelection != null &&
            studioSelection.matchesPhotos(_photos)
        ? studioSelection
        : null;
    if (_video == null && activeStudio != null) {
      final template = CinematicCatalog.byId(activeStudio.project.templateId);
      return GestureDetector(
        onTap: _busy ? null : _openStudio,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black,
            border: Border.all(color: _pink.withValues(alpha: .55)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AbsorbPointer(
                child: CinematicPreview(
                  photos: _photos.take(6).toList(growable: false),
                  template: template,
                  focalPoints: activeStudio.project.focalPoints,
                  playing: true,
                  playAudio: false,
                  borderRadius: 18,
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.movie_creation_rounded, color: _pink, size: 15),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'STUDIO VIDEO · publishes as a real MP4',
                          maxLines: 2,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
"""
if 'STUDIO VIDEO · publishes as a real MP4' not in s:
    marker = """  Widget _buildVideoPanel() {
    const canUploadVideo = true;
"""
    if marker not in s:
        raise SystemExit('AI Studio video-panel insertion marker not found')
    s = s.replace(marker, marker + studio_branch, 1)

s = replace_once(
    s,
    """      setState(() => _status = 'Uploading media and publishing…');
      final published = await notifier.publish();""",
    """      final selectedStudio = ref.read(studioListingSelectionProvider);
      final renderingStudio = _video == null &&
          selectedStudio != null &&
          selectedStudio.matchesPhotos(prepared.photos);
      setState(
        () => _status = renderingStudio
            ? 'Rendering your Studio video and publishing…'
            : 'Uploading media and publishing…',
      );
      final published = await notifier.publish();""",
    'AI Studio publish status',
)
p.write_text(s)


# MANUAL LISTING BUILDER -------------------------------------------------------
p = Path('lib/src/features/add/presentation/screens/add_listing_screen.dart')
s = p.read_text()
s = replace_once(
    s,
    "import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';\n",
    "import 'package:flutter_swipes/src/features/studio/data/cinematic_catalog.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/widgets/cinematic_preview.dart';\n",
    'manual Studio preview imports',
)

manual_preview = """  Widget _studioVideoPreview(
    BuildContext context,
    WidgetRef ref,
    StudioListingSelection studio,
  ) {
    final template = CinematicCatalog.byId(studio.project.templateId);
    return GestureDetector(
      onTap: () => _openStudio(context, ref),
      child: Container(
        height: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.brandPrimary.withAlpha(150)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(
              child: CinematicPreview(
                photos: draft.photos.take(6).toList(growable: false),
                template: template,
                focalPoints: studio.project.focalPoints,
                playing: true,
                playAudio: false,
                borderRadius: 20,
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(190),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.movie_creation_rounded,
                      color: AppTheme.brandPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'STUDIO VIDEO · VIDEO FIRST · final MP4 renders on Publish',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.tune_rounded, color: Colors.white, size: 17),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

"""
if '_studioVideoPreview(' not in s:
    marker = """  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const canUploadVideo = true;
"""
    if marker not in s:
        raise SystemExit('manual Studio preview insertion marker not found')
    s = s.replace(marker, manual_preview + marker, 1)

manual_selected_marker = """        if (draft.video == null) ...[
          SizedBox(height: 10),
          _MediaPickCard(
            icon: Icons.movie_creation_rounded,
            title: activeStudio == null
                ? 'Turn photos into video'
                : 'Studio video selected',
            subtitle: draft.photos.length < 3
                ? 'Add 3 photos first'
                : activeStudio == null
                ? 'Pan · zoom · cuts · split effects · sound'
                : 'Tap to preview or change the template',
            onTap: () => _openStudio(context, ref),
          ),
        ],
"""
manual_selected_new = manual_selected_marker + """        if (draft.video == null && activeStudio != null) ...[
          SizedBox(height: 10),
          _studioVideoPreview(context, ref, activeStudio),
        ],
"""
s = replace_once(
    s,
    manual_selected_marker,
    manual_selected_new,
    'manual selected Studio inline preview',
)
p.write_text(s)


# PUBLISH PIPELINE -------------------------------------------------------------
p = Path('lib/src/features/add/presentation/providers/add_listing_provider.dart')
s = p.read_text()
s = replace_once(
    s,
    """          final render = await ref.read(studioRenderRepositoryProvider).render(
            imageUrls: urls.take(6).toList(growable: false),
            project: studioSelection.project,
          );""",
    """          final render = await ref
              .read(studioRenderRepositoryProvider)
              .render(
                imageUrls: urls.take(6).toList(growable: false),
                project: studioSelection.project,
              )
              .timeout(
                const Duration(minutes: 4),
                onTimeout: () => throw Exception(
                  'Studio video took too long to render. Please retry — your photos are still here.',
                ),
              );""",
    'Studio render timeout and friendly failure',
)
p.write_text(s)

print('Studio publish + preview repair applied.')
