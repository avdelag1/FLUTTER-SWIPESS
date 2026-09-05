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
# Studio composer: make the UX explicit that the preview is not the final MP4.
# -----------------------------------------------------------------------------
p = Path('lib/src/features/studio/presentation/screens/studio_composer_screen.dart')
s = p.read_text()
s = replace_once(
    s,
    'Choose 3–6 photos. Swipess adds the pan, zoom, cuts, split reveals and sound — then renders a real vertical video when you publish.',
    'Choose 3–6 photos and a style. The preview below is only a live effect preview. Tap CREATE REAL VIDEO and Swipess will render the actual MP4, then show it in a real video player before you publish the listing.',
    'Studio composer explanation',
)
s = replace_once(
    s,
    "'USE THIS VIDEO STYLE'",
    "'CREATE REAL VIDEO'",
    'Studio composer CTA',
)
p.write_text(s)


# -----------------------------------------------------------------------------
# Publish provider: support a real MP4 render BEFORE the listing is inserted.
# -----------------------------------------------------------------------------
p = Path('lib/src/features/add/presentation/providers/add_listing_provider.dart')
s = p.read_text()
prepare_method = r'''  Future<bool> prepareStudioVideo() async {
    if (state.publishing) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        error: 'Session expired — sign in again before creating the Studio video.',
      );
      return false;
    }

    final selection = ref.read(studioListingSelectionProvider);
    if (selection == null || !selection.matchesPhotos(state.photos)) {
      state = state.copyWith(
        error: 'Choose a Studio video style again before creating the real video.',
      );
      return false;
    }
    if (selection.hasRenderedVideo) return true;
    if (state.photos.length < 3) {
      state = state.copyWith(error: 'Studio needs at least 3 photos.');
      return false;
    }

    try {
      final allowed = await Supabase.instance.client.rpc(
        'rpc_can_upload_listing_video',
      );
      if (allowed != true) {
        state = state.copyWith(
          error:
              'Listing video access could not be verified. Sign in again or retry.',
        );
        return false;
      }
    } catch (error) {
      debugPrint('[AddListing] Studio entitlement check failed: $error');
      state = state.copyWith(
        error: 'Could not verify video access. Please retry.',
      );
      return false;
    }

    state = state.copyWith(publishing: true, clearError: true);
    final repo = ref.read(listingRepositoryProvider);
    StudioRenderResult? render;
    try {
      final ai = ref.read(aiEdgeRepositoryProvider);
      final urls = await repo.uploadListingPhotos(
        userId: user.id,
        files: state.photos,
        moderateImage: ai.assertImageSafe,
      );
      if (urls.length < 3) {
        throw Exception(
          'Studio needs at least 3 approved photos. Choose another photo and try again.',
        );
      }

      render = await ref
          .read(studioRenderRepositoryProvider)
          .render(
            imageUrls: urls.take(6).toList(growable: false),
            project: selection.project,
          )
          .timeout(
            const Duration(minutes: 4),
            onTimeout: () => throw Exception(
              'Studio video took too long to render. Please retry — your photos are still here.',
            ),
          );

      final stored = ref
          .read(studioListingSelectionProvider.notifier)
          .setRendered(
            photos: state.photos,
            uploadedImageUrls: urls,
            videoUrl: render.videoUrl,
            posterUrl: render.posterUrl,
            durationSeconds: render.durationSeconds,
          );
      if (!stored) {
        await ref.read(studioRenderRepositoryProvider).cleanup(render);
        throw Exception(
          'The Studio photos changed while the video was rendering. Please create the video again.',
        );
      }

      state = state.copyWith(publishing: false, clearError: true);
      return true;
    } catch (error) {
      if (render != null) {
        await ref.read(studioRenderRepositoryProvider).cleanup(render);
      }
      state = state.copyWith(
        publishing: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

'''
if 'Future<bool> prepareStudioVideo() async' not in s:
    marker = '  Future<bool> publish() async {\n'
    if marker not in s:
        raise SystemExit('prepareStudioVideo insertion marker not found')
    s = s.replace(marker, prepare_method + marker, 1)

old_else = r'''      } else {
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
new_else = r'''      } else {
        final preparedStudio = usableStudio ? studioSelection : null;
        if (preparedStudio != null &&
            preparedStudio.hasRenderedVideo &&
            preparedStudio.uploadedImageUrls.length >= 3) {
          // The user already waited for and confirmed the REAL MP4 in the
          // listing creator. Reuse those exact uploaded photos + video instead
          // of rendering a second time during Publish.
          urls = preparedStudio.uploadedImageUrls;
          videoUrl = preparedStudio.renderedVideoUrl;
          generatedStudioRender = StudioRenderResult(
            videoUrl: preparedStudio.renderedVideoUrl!,
            posterUrl: preparedStudio.renderedPosterUrl,
            durationSeconds: preparedStudio.renderedDurationSeconds ?? 0,
          );
          studioGenerated = true;
        } else {
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
      }
'''
s = replace_once(s, old_else, new_else, 'Publish reuses confirmed Studio MP4')
s = replace_once(
    s,
    '''      if (generatedStudioRender != null) {
        await ref
            .read(studioRenderRepositoryProvider)
            .cleanup(generatedStudioRender);
      }
''',
    '''      if (generatedStudioRender != null) {
        await ref
            .read(studioRenderRepositoryProvider)
            .cleanup(generatedStudioRender);
        ref.read(studioListingSelectionProvider.notifier).clearRendered();
      }
''',
    'Clear confirmed render after failed listing insert',
)
p.write_text(s)


# -----------------------------------------------------------------------------
# Manual listing creator: render immediately after choosing the Studio style,
# then replace the fake animation with the REAL network MP4 video player.
# -----------------------------------------------------------------------------
p = Path('lib/src/features/add/presentation/screens/add_listing_screen.dart')
s = p.read_text()
s = replace_once(
    s,
    '''    ref.read(studioListingSelectionProvider.notifier).set(
      project: result.project,
      photos: nextPhotos,
    );
  }
''',
    '''    ref.read(studioListingSelectionProvider.notifier).set(
      project: result.project,
      photos: nextPhotos,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating the real Studio MP4… please wait.')),
    );
    final ready = await ref
        .read(addListingProvider.notifier)
        .prepareStudioVideo();
    if (!context.mounted) return;
    final error = ref.read(addListingProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ready
              ? 'Real Studio video ready — play it below before publishing.'
              : (error ?? 'Studio video could not be created. Please retry.'),
        ),
      ),
    );
  }
''',
    'Manual Studio auto-render after style save',
)

manual_ready = r'''    if (studio.hasRenderedVideo) {
      return Container(
        height: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF34D399), width: 1.4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListingVideoInlinePreview(
              networkUrl: studio.renderedVideoUrl!,
              muted: false,
              height: 280,
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(185),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 17),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'REAL MP4 READY · PLAY TO CONFIRM',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 9.5,
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
      );
    }
'''
marker = '''  ) {
    final template = CinematicCatalog.byId(studio.project.templateId);
'''
if 'REAL MP4 READY · PLAY TO CONFIRM' not in s:
    if marker not in s:
        raise SystemExit('Manual real-player insertion marker not found')
    s = s.replace(marker, '  ) {\n' + manual_ready + '    final template = CinematicCatalog.byId(studio.project.templateId);\n', 1)

s = s.replace(
    'STUDIO VIDEO · VIDEO FIRST · final MP4 renders on Publish',
    'STUDIO PREVIEW ONLY · choose a style to create the real MP4',
    1,
)
s = s.replace(
    "                : 'Studio video selected',",
    "                : activeStudio.hasRenderedVideo\n                ? 'Real Studio video ready'\n                : 'Studio style selected',",
    1,
)
s = s.replace(
    "                : 'Tap to preview or change the template',",
    "                : activeStudio.hasRenderedVideo\n                ? 'Play the real MP4 below · tap here to change style'\n                : 'Creating real MP4 after style confirmation',",
    1,
)
p.write_text(s)


# -----------------------------------------------------------------------------
# AI listing creator: same behavior. Selecting a style immediately uploads the
# approved photos + renders the real MP4. The panel then becomes a real player.
# -----------------------------------------------------------------------------
p = Path('lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart')
s = p.read_text()
s = replace_once(
    s,
    '''    ref.read(studioListingSelectionProvider.notifier).set(
      project: result.project,
      photos: nextPhotos,
    );
  }
''',
    '''    ref.read(studioListingSelectionProvider.notifier).set(
      project: result.project,
      photos: nextPhotos,
    );

    final notifier = ref.read(addListingProvider.notifier);
    notifier.update(
      (current) => current.copyWith(photos: List<XFile>.of(nextPhotos)),
    );
    setState(() {
      _busy = true;
      _status = 'Creating the REAL Studio MP4…';
    });
    final ready = await notifier.prepareStudioVideo();
    if (!mounted) return;
    final error = ref.read(addListingProvider).error;
    setState(() {
      _busy = false;
      _status = ready
          ? 'REAL Studio video ready ✓ — play it before publishing'
          : (error ?? 'Studio video could not be created. Please retry.');
    });
  }
''',
    'AI Studio auto-render after style save',
)

ready_branch = r'''    if (_video == null && activeStudio != null && activeStudio.hasRenderedVideo) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black,
          border: Border.all(color: const Color(0xFF34D399), width: 1.4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListingVideoInlinePreview(
              networkUrl: activeStudio.renderedVideoUrl!,
              muted: false,
              height: 520,
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 15),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'REAL MP4 READY · PLAY TO CONFIRM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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
      );
    }
'''
marker = '''    if (_video == null && activeStudio != null) {
'''
if 'REAL MP4 READY · PLAY TO CONFIRM' not in s:
    if marker not in s:
        raise SystemExit('AI real-player insertion marker not found')
    s = s.replace(marker, ready_branch + marker, 1)

s = s.replace(
    'STUDIO VIDEO · publishes as a real MP4',
    'STUDIO PREVIEW ONLY · creating the real MP4 after confirmation',
    1,
)
s = replace_once(
    s,
    '''      final renderingStudio = _video == null &&
          selectedStudio != null &&
          selectedStudio.matchesPhotos(prepared.photos);
''',
    '''      final renderingStudio = _video == null &&
          selectedStudio != null &&
          selectedStudio.matchesPhotos(prepared.photos) &&
          !selectedStudio.hasRenderedVideo;
''',
    'AI publish knows about pre-rendered Studio video',
)
p.write_text(s)

print('Studio real-video confirmation flow applied.')
