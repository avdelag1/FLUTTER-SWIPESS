from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f'{label}: already applied')
        return text
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    print(f'{label}: patched')
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# 1) Studio itself must create the REAL MP4 and show a real player BEFORE exit.
# -----------------------------------------------------------------------------
p = Path('lib/src/features/studio/presentation/screens/studio_composer_screen.dart')
s = p.read_text()

s = replace_once(
    s,
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\nimport 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';\n",
    'Studio imports real video player',
)

s = replace_once(
    s,
    '''class StudioComposerResult {\n  const StudioComposerResult({required this.project, required this.photos});\n\n  final StudioProject project;\n  final List<XFile> photos;\n}\n\nclass StudioComposerScreen extends StatefulWidget {\n''',
    '''class StudioComposerResult {\n  const StudioComposerResult({required this.project, required this.photos});\n\n  final StudioProject project;\n  final List<XFile> photos;\n}\n\nclass StudioRenderedVideo {\n  const StudioRenderedVideo({\n    required this.videoUrl,\n    this.posterUrl,\n    required this.durationSeconds,\n  });\n\n  final String videoUrl;\n  final String? posterUrl;\n  final double durationSeconds;\n}\n\ntypedef StudioRealVideoRenderer = Future<StudioRenderedVideo> Function(\n  StudioComposerResult result,\n);\n\nclass StudioComposerScreen extends StatefulWidget {\n''',
    'Studio rendered-video contract',
)

s = replace_once(
    s,
    '''    required this.listingCategory,\n    this.initialProject,\n  });\n\n  final List<XFile> photos;\n  final String listingCategory;\n  final StudioProject? initialProject;\n''',
    '''    required this.listingCategory,\n    this.initialProject,\n    this.onCreateRealVideo,\n  });\n\n  final List<XFile> photos;\n  final String listingCategory;\n  final StudioProject? initialProject;\n  final StudioRealVideoRenderer? onCreateRealVideo;\n''',
    'Studio renderer callback field',
)

s = replace_once(
    s,
    '''  int _selectedPhoto = 0;\n  bool _playing = true;\n''',
    '''  int _selectedPhoto = 0;\n  bool _playing = true;\n  bool _renderingRealVideo = false;\n  String? _realVideoError;\n  StudioRenderedVideo? _renderedVideo;\n''',
    'Studio render state',
)

s = replace_once(
    s,
    '''  void _setFocal({double? x, double? y}) {\n    final current = _activeFocal;\n    setState(() {\n      _focalPoints[_selectedPhoto] = StudioFocalPoint(\n''',
    '''  void _setFocal({double? x, double? y}) {\n    final current = _activeFocal;\n    setState(() {\n      _renderedVideo = null;\n      _realVideoError = null;\n      _focalPoints[_selectedPhoto] = StudioFocalPoint(\n''',
    'Focal edit invalidates render',
)

s = replace_once(
    s,
    '''  void _selectTemplate(CinematicTemplate template) {\n    setState(() {\n      _templateId = template.id;\n''',
    '''  void _selectTemplate(CinematicTemplate template) {\n    setState(() {\n      _renderedVideo = null;\n      _realVideoError = null;\n      _templateId = template.id;\n''',
    'Template edit invalidates render',
)

s = replace_once(
    s,
    '''    setState(() {\n      _focalPoints = <int, StudioFocalPoint>{\n''',
    '''    setState(() {\n      _renderedVideo = null;\n      _realVideoError = null;\n      _focalPoints = <int, StudioFocalPoint>{\n''',
    'Reorder invalidates render',
)

# Sound selection must invalidate an already-rendered file too.
s = replace_once(
    s,
    '''      onSelected: (_) => setState(() {\n        _audioPresetId = preset.id;\n        _playing = true;\n      }),\n''',
    '''      onSelected: (_) => setState(() {\n        _renderedVideo = null;\n        _realVideoError = null;\n        _audioPresetId = preset.id;\n        _playing = true;\n      }),\n''',
    'Sound edit invalidates render',
)

create_method = r'''  Future<void> _createRealVideo() async {
    if (_renderingRealVideo) return;
    final renderer = widget.onCreateRealVideo;
    if (renderer == null) {
      setState(() {
        _realVideoError =
            'Studio renderer is not connected. Close Studio, reopen it and try again.';
      });
      return;
    }

    setState(() {
      _renderingRealVideo = true;
      _realVideoError = null;
      _renderedVideo = null;
      _playing = false;
    });

    try {
      final rendered = await renderer(
        StudioComposerResult(
          project: _project,
          photos: List<XFile>.unmodifiable(_photos),
        ),
      );
      if (!mounted) return;
      if (rendered.videoUrl.trim().isEmpty) {
        throw Exception('Renderer returned an empty MP4 URL.');
      }
      setState(() {
        _renderingRealVideo = false;
        _renderedVideo = rendered;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _renderingRealVideo = false;
        _realVideoError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('ClientException: ', '');
      });
    }
  }

'''
if 'Future<void> _createRealVideo() async' not in s:
    marker = '  @override\n  Widget build(BuildContext context) {\n'
    if marker not in s:
        raise SystemExit('Studio create method marker not found')
    s = s.replace(marker, create_method + marker, 1)

old_preview = r'''            if (!canUse)
              _notice(
                icon: Icons.photo_library_outlined,
                text: _photos.length < 3
                    ? 'Add at least 3 photos to use Studio.'
                    : 'Studio uses a maximum of 6 photos.',
              )
            else
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: CinematicPreview(
                    key: ValueKey(
                      '${_templateId}_${_audioPresetId}_${_photos.length}',
                    ),
                    photos: _photos,
                    template: _previewTemplate,
                    focalPoints: _focalPoints,
                    playing: _playing,
                    playAudio: true,
                  ),
                ),
              ),
'''
new_preview = r'''            if (_renderedVideo != null)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Container(
                    height: 520,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF34D399),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ListingVideoInlinePreview(
                          networkUrl: _renderedVideo!.videoUrl,
                          muted: false,
                          height: 520,
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .72),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF34D399),
                                    size: 18,
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'REAL MP4 CREATED · PLAY IT BEFORE USING',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (!canUse)
              _notice(
                icon: Icons.photo_library_outlined,
                text: _photos.length < 3
                    ? 'Add at least 3 photos to use Studio.'
                    : 'Studio uses a maximum of 6 photos.',
              )
            else
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: CinematicPreview(
                    key: ValueKey(
                      '${_templateId}_${_audioPresetId}_${_photos.length}',
                    ),
                    photos: _photos,
                    template: _previewTemplate,
                    focalPoints: _focalPoints,
                    playing: _playing,
                    playAudio: true,
                  ),
                ),
              ),
'''
s = replace_once(s, old_preview, new_preview, 'Studio real MP4 player')

old_button = r'''            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: !canUse
                    ? null
                    : () => Navigator.of(context).pop(
                        StudioComposerResult(
                          project: _project,
                          photos: List<XFile>.unmodifiable(_photos),
                        ),
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: _pink,
                  disabledBackgroundColor: _pink.withValues(alpha: .35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.movie_creation_rounded),
                label: Text(
                  'CREATE REAL VIDEO',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
              ),
            ),
'''
new_button = r'''            const SizedBox(height: 22),
            if (_renderingRealVideo)
              _notice(
                icon: Icons.hourglass_top_rounded,
                text:
                    'Rendering the real MP4 now. Keep Studio open — the listing cannot publish until the video exists.',
              ),
            if (_realVideoError != null) ...[
              _notice(
                icon: Icons.error_outline_rounded,
                text: _realVideoError!,
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: !canUse || _renderingRealVideo
                    ? null
                    : _renderedVideo == null
                    ? _createRealVideo
                    : () => Navigator.of(context).pop(
                        StudioComposerResult(
                          project: _project,
                          photos: List<XFile>.unmodifiable(_photos),
                        ),
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: _renderedVideo == null
                      ? _pink
                      : const Color(0xFF16A34A),
                  disabledBackgroundColor: _pink.withValues(alpha: .35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _renderingRealVideo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _renderedVideo == null
                            ? Icons.movie_creation_rounded
                            : Icons.check_circle_rounded,
                      ),
                label: Text(
                  _renderingRealVideo
                      ? 'RENDERING REAL MP4…'
                      : _renderedVideo == null
                      ? 'CREATE REAL VIDEO'
                      : 'USE THIS REAL VIDEO',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
              ),
            ),
            if (_renderedVideo != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _renderedVideo = null;
                  _realVideoError = null;
                  _playing = true;
                }),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('EDIT STYLE AND RENDER AGAIN'),
              ),
            ],
'''
s = replace_once(s, old_button, new_button, 'Studio two-stage create/use CTA')
p.write_text(s)


# -----------------------------------------------------------------------------
# 2) Parents provide the renderer callback. Studio no longer exits before MP4.
# -----------------------------------------------------------------------------

def patch_parent(path: str, photos_expr: str, category_expr: str, is_ai: bool) -> None:
    p = Path(path)
    s = p.read_text()
    constructor = f'''            builder: (_) => StudioComposerScreen(\n              photos: {photos_expr},\n              listingCategory: {category_expr},\n              initialProject: initialProject,\n            ),\n'''
    callback = f'''            builder: (_) => StudioComposerScreen(\n              photos: {photos_expr},\n              listingCategory: {category_expr},\n              initialProject: initialProject,\n              onCreateRealVideo: (studioResult) async {{\n                final nextPhotos = <XFile>[\n                  ...studioResult.photos,\n                  ...{photos_expr}.skip(6),\n                ];\n                final notifier = ref.read(addListingProvider.notifier);\n                notifier.update(\n                  (current) => current.copyWith(\n                    photos: List<XFile>.of(nextPhotos),\n                  ),\n                );\n                ref.read(studioListingSelectionProvider.notifier).set(\n                  project: studioResult.project,\n                  photos: nextPhotos,\n                );\n                final ready = await notifier.prepareStudioVideo();\n                if (!ready) {{\n                  throw Exception(\n                    ref.read(addListingProvider).error ??\n                        'Studio could not create the MP4. Please retry.',\n                  );\n                }}\n                final rendered = ref.read(studioListingSelectionProvider);\n                if (rendered == null ||\n                    !rendered.hasRenderedVideo ||\n                    !rendered.matchesPhotos(nextPhotos)) {{\n                  throw Exception(\n                    'Studio did not receive a confirmed MP4. Please retry.',\n                  );\n                }}\n                return StudioRenderedVideo(\n                  videoUrl: rendered.renderedVideoUrl!,\n                  posterUrl: rendered.renderedPosterUrl,\n                  durationSeconds: rendered.renderedDurationSeconds ?? 0,\n                );\n              }},\n            ),\n'''
    s = replace_once(s, constructor, callback, f'{path} Studio callback')

    if is_ai:
        old_after = '''    if (result == null || !mounted) return;\n    final nextPhotos = <XFile>[...result.photos, ..._photos.skip(6)];\n    setState(() {\n      _photos\n        ..clear()\n        ..addAll(nextPhotos);\n      _video = null;\n      _backgroundMusic = null;\n      _backgroundMusicPreset = null;\n      _backgroundMusicName = null;\n      _videoAudioEnabled = true;\n    });\n    ref.read(studioListingSelectionProvider.notifier).set(\n      project: result.project,\n      photos: nextPhotos,\n    );\n\n    final notifier = ref.read(addListingProvider.notifier);\n    notifier.update(\n      (current) => current.copyWith(photos: List<XFile>.of(nextPhotos)),\n    );\n    setState(() {\n      _busy = true;\n      _status = 'Creating the REAL Studio MP4…';\n    });\n    final ready = await notifier.prepareStudioVideo();\n    if (!mounted) return;\n    final error = ref.read(addListingProvider).error;\n    setState(() {\n      _busy = false;\n      _status = ready\n          ? 'REAL Studio video ready ✓ — play it before publishing'\n          : (error ?? 'Studio video could not be created. Please retry.');\n    });\n'''
        new_after = '''    if (result == null || !mounted) return;\n    final nextPhotos = <XFile>[...result.photos, ..._photos.skip(6)];\n    final rendered = ref.read(studioListingSelectionProvider);\n    if (rendered == null ||\n        !rendered.hasRenderedVideo ||\n        !rendered.matchesPhotos(nextPhotos)) {\n      setState(() {\n        _status = 'Studio did not finish a real MP4. Reopen Studio and retry.';\n      });\n      return;\n    }\n    setState(() {\n      _photos\n        ..clear()\n        ..addAll(nextPhotos);\n      _video = null;\n      _backgroundMusic = null;\n      _backgroundMusicPreset = null;\n      _backgroundMusicName = null;\n      _videoAudioEnabled = true;\n      _busy = false;\n      _status = 'REAL Studio MP4 ready ✓ — play it before publishing';\n    });\n    ref.read(addListingProvider.notifier).update(\n      (current) => current.copyWith(photos: List<XFile>.of(nextPhotos)),\n    );\n'''
    else:
        old_after = '''    if (result == null || !context.mounted) return;\n    final nextPhotos = <XFile>[\n      ...result.photos,\n      ...draft.photos.skip(6),\n    ];\n    ref.read(addListingProvider.notifier).update(\n      (current) => current.copyWith(photos: nextPhotos),\n    );\n    ref.read(studioListingSelectionProvider.notifier).set(\n      project: result.project,\n      photos: nextPhotos,\n    );\n\n    ScaffoldMessenger.of(context).showSnackBar(\n      const SnackBar(content: Text('Creating the real Studio MP4… please wait.')),\n    );\n    final ready = await ref\n        .read(addListingProvider.notifier)\n        .prepareStudioVideo();\n    if (!context.mounted) return;\n    final error = ref.read(addListingProvider).error;\n    ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(\n        content: Text(\n          ready\n              ? 'Real Studio video ready — play it below before publishing.'\n              : (error ?? 'Studio video could not be created. Please retry.'),\n        ),\n      ),\n    );\n'''
        new_after = '''    if (result == null || !context.mounted) return;\n    final nextPhotos = <XFile>[\n      ...result.photos,\n      ...draft.photos.skip(6),\n    ];\n    final rendered = ref.read(studioListingSelectionProvider);\n    if (rendered == null ||\n        !rendered.hasRenderedVideo ||\n        !rendered.matchesPhotos(nextPhotos)) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(\n          content: Text('Studio did not finish a real MP4. Reopen Studio and retry.'),\n        ),\n      );\n      return;\n    }\n    ref.read(addListingProvider.notifier).update(\n      (current) => current.copyWith(photos: nextPhotos),\n    );\n    ScaffoldMessenger.of(context).showSnackBar(\n      const SnackBar(\n        content: Text('Real Studio MP4 ready — play it below, then publish.'),\n      ),\n    );\n'''
    s = replace_once(s, old_after, new_after, f'{path} stop post-pop fake render')
    p.write_text(s)


patch_parent(
    'lib/src/features/add/presentation/screens/add_listing_screen.dart',
    'draft.photos',
    'draft.categoryValue',
    False,
)
patch_parent(
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    '_photos',
    '_category',
    True,
)


# -----------------------------------------------------------------------------
# 3) Publishing MUST NOT silently downgrade a failed Studio project to photos.
# -----------------------------------------------------------------------------
p = Path('lib/src/features/add/presentation/providers/add_listing_provider.dart')
s = p.read_text()

s = replace_once(
    s,
    '''    final studioSelection = ref.read(studioListingSelectionProvider);\n    final usableStudio = studioSelection != null &&\n        studioSelection.matchesPhotos(state.photos);\n\n    try {\n''',
    '''    final studioSelection = ref.read(studioListingSelectionProvider);\n    final usableStudio = studioSelection != null &&\n        studioSelection.matchesPhotos(state.photos);\n    final studioIntent = state.video == null && studioSelection != null;\n\n    // Studio is an explicit promise to publish a VIDEO. Never silently fall\n    // back to a normal photo listing just because photos changed or rendering\n    // failed. This is exactly what made an extra fourth photo appear to \"fix\"\n    // publishing while actually discarding the requested Studio video.\n    if (studioIntent && !usableStudio) {\n      state = state.copyWith(\n        error:\n            'Your Studio photos changed. Reopen Studio and create the real MP4 again before publishing.',\n      );\n      return false;\n    }\n    if (studioIntent &&\n        (!studioSelection!.hasRenderedVideo ||\n            studioSelection.uploadedImageUrls.length < 3)) {\n      state = state.copyWith(\n        error:\n            'Studio is not finished yet. Create and play the REAL MP4 inside Studio before publishing.',\n      );\n      return false;\n    }\n\n    try {\n''',
    'Block Studio downgrade to photo listing',
)

old_fallback = r'''        } else {
          // Compatibility fallback for older clients / drafts: render on
          // Publish if the explicit pre-render step was not completed.
          urls = await repo.uploadListingPhotos(
            userId: user.id,
            files: state.photos,
            moderateImage: ai.assertImageSafe,
          );
          if (usableStudio && studioSelection != null) {
            if (urls.length < 3) {
              throw Exception(
                'Studio needs at least 3 approved photos. Choose another photo and try again.',
              );
            }
            final render = await ref
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
                );
            generatedStudioRender = render;
            videoUrl = render.videoUrl;
            studioGenerated = true;
          }
        }
'''
new_fallback = r'''        } else {
          // Pure photo listing only. If Studio was selected, the preflight
          // above requires a confirmed real MP4 and this branch is unreachable.
          urls = await repo.uploadListingPhotos(
            userId: user.id,
            files: state.photos,
            moderateImage: ai.assertImageSafe,
          );
        }
'''
s = replace_once(s, old_fallback, new_fallback, 'Remove render-on-publish fallback')
p.write_text(s)


# -----------------------------------------------------------------------------
# 4) Quick filters must put the newest created listing first, not RPC relevance.
# -----------------------------------------------------------------------------
p = Path('lib/src/features/swipes/presentation/providers/swipe_providers.dart')
s = p.read_text()
old_preview_provider = r'''      final repository = ref.read(marketSwipeRepositoryProvider);
      return repository.fetch(
        category: category,
        marketCity: discovery.city,
        marketCountry: discovery.country,
        limit: 8,
      );
    });
'''
new_preview_provider = r'''      final repository = ref.read(marketSwipeRepositoryProvider);
      final listings = await repository.fetch(
        category: category,
        marketCity: discovery.city,
        marketCountry: discovery.country,
        limit: 8,
      );
      // Dashboard previews are chronological: the latest listing created by
      // another account must be the first card shown for that category.
      final ordered = List<Listing>.from(listings);
      ordered.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return ordered;
    });
'''
s = replace_once(s, old_preview_provider, new_preview_provider, 'Newest quick-filter listing first')
p.write_text(s)

print('Studio in-place render + newest-first patch complete.')
