from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing integration marker in {path}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1))


def replace_all(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        return
    path.write_text(text.replace(old, new))


provider = ROOT / 'lib/src/features/add/presentation/providers/add_listing_provider.dart'
replace_once(
    provider,
    "import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';\n",
    "import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/data/studio_render_repository.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';\n",
)
replace_once(
    provider,
    "    final currency = state.currency.trim().toUpperCase();\n"
    "    if (!const {'USD', 'MXN'}.contains(currency)) {\n"
    "      state = state.copyWith(error: 'Choose USD or MXN for the price.');\n"
    "      return false;\n"
    "    }\n\n"
    "    try {\n",
    "    final currency = state.currency.trim().toUpperCase();\n"
    "    if (!const {'USD', 'MXN'}.contains(currency)) {\n"
    "      state = state.copyWith(error: 'Choose USD or MXN for the price.');\n"
    "      return false;\n"
    "    }\n\n"
    "    final studioSelection = ref.read(studioListingSelectionProvider);\n"
    "    final usableStudio = studioSelection != null &&\n"
    "        studioSelection.matchesPhotos(state.photos);\n\n"
    "    try {\n",
)
replace_once(
    provider,
    "    if (state.video != null) {\n"
    "      try {\n"
    "        final allowed = await Supabase.instance.client.rpc(\n"
    "          'rpc_can_upload_listing_video',\n"
    "        );\n",
    "    if (state.video != null || usableStudio) {\n"
    "      try {\n"
    "        final allowed = await Supabase.instance.client.rpc(\n"
    "          'rpc_can_upload_listing_video',\n"
    "        );\n",
)
old_media = """      final photosFuture = repo.uploadListingPhotos(
        userId: user.id,
        files: state.photos,
        moderateImage: ai.assertImageSafe,
      );
      final videoFuture = video == null
          ? Future<String?>.value(null)
          : repo
                .uploadListingVideo(userId: user.id, file: video)
                .then<String?>((url) => url);
      final musicFuture = video == null || backgroundMusic == null
          ? Future<String?>.value(null)
          : repo.uploadListingAudio(userId: user.id, file: backgroundMusic);

      final uploadedMedia = await Future.wait<Object?>([
        photosFuture,
        videoFuture,
        musicFuture,
      ]);
      final urls = uploadedMedia[0] as List<String>;
      final videoUrl = uploadedMedia[1] as String?;
      final backgroundMusicUrl = uploadedMedia[2] as String?;
      final payload = _payload(
        user.id,
        urls,
        coords,
        videoUrl: videoUrl,
        backgroundMusicUrl: backgroundMusicUrl,
      );
"""
new_media = """      late final List<String> urls;
      String? videoUrl;
      String? backgroundMusicUrl;
      var studioGenerated = false;

      if (video != null) {
        final uploadedMedia = await Future.wait<Object?>([
          repo.uploadListingPhotos(
            userId: user.id,
            files: state.photos,
            moderateImage: ai.assertImageSafe,
          ),
          repo
              .uploadListingVideo(userId: user.id, file: video)
              .then<String?>((url) => url),
          backgroundMusic == null
              ? Future<String?>.value(null)
              : repo.uploadListingAudio(userId: user.id, file: backgroundMusic),
        ]);
        urls = uploadedMedia[0] as List<String>;
        videoUrl = uploadedMedia[1] as String?;
        backgroundMusicUrl = uploadedMedia[2] as String?;
      } else {
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
          final render = await ref.read(studioRenderRepositoryProvider).render(
            imageUrls: urls.take(6).toList(growable: false),
            project: studioSelection.project,
          );
          videoUrl = render.videoUrl;
          studioGenerated = true;
        }
      }

      final payload = _payload(
        user.id,
        urls,
        coords,
        videoUrl: videoUrl,
        backgroundMusicUrl: backgroundMusicUrl,
        studioGenerated: studioGenerated,
      );
"""
replace_once(provider, old_media, new_media)
replace_once(
    provider,
    "    String? videoUrl,\n"
    "    String? backgroundMusicUrl,\n"
    "  }) {\n",
    "    String? videoUrl,\n"
    "    String? backgroundMusicUrl,\n"
    "    bool studioGenerated = false,\n"
    "  }) {\n",
)
replace_once(
    provider,
    "      'video_url': videoUrl,\n"
    "      'video_audio_enabled': draft.videoAudioEnabled,\n"
    "      'background_music_url': backgroundMusicUrl,\n"
    "      'background_music_preset': draft.backgroundMusicPreset,\n"
    "      'background_music_name': draft.backgroundMusicName,\n",
    "      'video_url': videoUrl,\n"
    "      // Studio bakes its selected soundscape directly into the generated\n"
    "      // MP4. Do not also attach listing soundtrack metadata or playback\n"
    "      // would layer the same vibe over the rendered audio a second time.\n"
    "      'video_audio_enabled': studioGenerated ? true : draft.videoAudioEnabled,\n"
    "      'background_music_url': studioGenerated ? null : backgroundMusicUrl,\n"
    "      'background_music_preset': studioGenerated\n"
    "          ? null\n"
    "          : draft.backgroundMusicPreset,\n"
    "      'background_music_name': studioGenerated ? null : draft.backgroundMusicName,\n",
)
replace_once(
    provider,
    "      ref.invalidate(ownerListingsStatsProvider);\n"
    "      state = const ListingDraft();\n",
    "      ref.invalidate(ownerListingsStatsProvider);\n"
    "      ref.read(studioListingSelectionProvider.notifier).clear();\n"
    "      state = const ListingDraft();\n",
)

manual = ROOT / 'lib/src/features/add/presentation/screens/add_listing_screen.dart'
replace_once(
    manual,
    "import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';\n",
    "import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/screens/studio_composer_screen.dart';\n",
)
replace_once(
    manual,
    "  Widget _buildPhotoTile(\n",
    "  Future<void> _openStudio(BuildContext context, WidgetRef ref) async {\n"
    "    if (draft.photos.length < 3) {\n"
    "      ScaffoldMessenger.of(context).showSnackBar(\n"
    "        const SnackBar(content: Text('Add at least 3 photos first.')),\n"
    "      );\n"
    "      return;\n"
    "    }\n"
    "    final selection = ref.read(studioListingSelectionProvider);\n"
    "    final initialProject = selection != null && selection.matchesPhotos(draft.photos)\n"
    "        ? selection.project\n"
    "        : null;\n"
    "    final result = await Navigator.of(context, rootNavigator: true)\n"
    "        .push<StudioComposerResult>(\n"
    "          MaterialPageRoute(\n"
    "            builder: (_) => StudioComposerScreen(\n"
    "              photos: draft.photos,\n"
    "              listingCategory: draft.categoryValue,\n"
    "              initialProject: initialProject,\n"
    "            ),\n"
    "          ),\n"
    "        );\n"
    "    if (result == null || !context.mounted) return;\n"
    "    final nextPhotos = <XFile>[\n"
    "      ...result.photos,\n"
    "      ...draft.photos.skip(6),\n"
    "    ];\n"
    "    ref.read(addListingProvider.notifier).update(\n"
    "      (current) => current.copyWith(photos: nextPhotos),\n"
    "    );\n"
    "    ref.read(studioListingSelectionProvider.notifier).set(\n"
    "      project: result.project,\n"
    "      photos: nextPhotos,\n"
    "    );\n"
    "  }\n\n"
    "  Widget _buildPhotoTile(\n",
)
replace_once(
    manual,
    "  Widget build(BuildContext context, WidgetRef ref) {\n"
    "    const canUploadVideo = true;\n\n"
    "    return Column(\n",
    "  Widget build(BuildContext context, WidgetRef ref) {\n"
    "    const canUploadVideo = true;\n"
    "    final studioSelection = ref.watch(studioListingSelectionProvider);\n"
    "    final activeStudio = studioSelection != null &&\n"
    "            studioSelection.matchesPhotos(draft.photos)\n"
    "        ? studioSelection\n"
    "        : null;\n\n"
    "    return Column(\n",
)
manual_tip = """        Text(
          'Video tip: shoot/upload portrait 9:16 in high quality (1080×1920 preferred) so it fills the dashboard card.',
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.faint(context),
            fontSize: 9.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
"""
manual_tip_new = manual_tip + """        if (draft.video == null) ...[
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
replace_once(manual, manual_tip, manual_tip_new)
replace_all(
    manual,
    "    if (cropped != null && context.mounted) {\n"
    "      ref.read(addListingProvider.notifier).setVideo(cropped);\n"
    "    }\n",
    "    if (cropped != null && context.mounted) {\n"
    "      ref.read(studioListingSelectionProvider.notifier).clear();\n"
    "      ref.read(addListingProvider.notifier).setVideo(cropped);\n"
    "    }\n",
)

ai = ROOT / 'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart'
replace_once(
    ai,
    "import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';\n",
    "import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';\n"
    "import 'package:flutter_swipes/src/features/studio/presentation/screens/studio_composer_screen.dart';\n",
)
replace_once(
    ai,
    "  Future<bool> _ensurePaidVideoAccess() async {\n",
    "  Future<void> _openStudio() async {\n"
    "    if (_busy) return;\n"
    "    if (_photos.length < 3) {\n"
    "      _showMessage('Add at least 3 photos first.');\n"
    "      return;\n"
    "    }\n"
    "    final selection = ref.read(studioListingSelectionProvider);\n"
    "    final initialProject = selection != null && selection.matchesPhotos(_photos)\n"
    "        ? selection.project\n"
    "        : null;\n"
    "    final result = await Navigator.of(context, rootNavigator: true)\n"
    "        .push<StudioComposerResult>(\n"
    "          MaterialPageRoute(\n"
    "            builder: (_) => StudioComposerScreen(\n"
    "              photos: _photos,\n"
    "              listingCategory: _category,\n"
    "              initialProject: initialProject,\n"
    "            ),\n"
    "          ),\n"
    "        );\n"
    "    if (result == null || !mounted) return;\n"
    "    final nextPhotos = <XFile>[...result.photos, ..._photos.skip(6)];\n"
    "    setState(() {\n"
    "      _photos\n"
    "        ..clear()\n"
    "        ..addAll(nextPhotos);\n"
    "      _video = null;\n"
    "      _backgroundMusic = null;\n"
    "      _backgroundMusicPreset = null;\n"
    "      _backgroundMusicName = null;\n"
    "      _videoAudioEnabled = true;\n"
    "    });\n"
    "    ref.read(studioListingSelectionProvider.notifier).set(\n"
    "      project: result.project,\n"
    "      photos: nextPhotos,\n"
    "    );\n"
    "  }\n\n"
    "  Future<bool> _ensurePaidVideoAccess() async {\n",
)
replace_all(
    ai,
    "    if (cropped != null && mounted) setState(() => _video = cropped);\n",
    "    if (cropped != null && mounted) {\n"
    "      ref.read(studioListingSelectionProvider.notifier).clear();\n"
    "      setState(() => _video = cropped);\n"
    "    }\n",
)
replace_once(
    ai,
    "  Widget _mediaSection(int photoLimit) {\n"
    "    return Column(\n",
    "  Widget _mediaSection(int photoLimit) {\n"
    "    final studioSelection = ref.watch(studioListingSelectionProvider);\n"
    "    final activeStudio = studioSelection != null &&\n"
    "            studioSelection.matchesPhotos(_photos)\n"
    "        ? studioSelection\n"
    "        : null;\n"
    "    return Column(\n",
)
ai_tip = """        Text(
          'For dashboard cards, use a sharp portrait 9:16 video (1080×1920 preferred).',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8F8F98),
            fontSize: 9.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
"""
ai_tip_new = ai_tip + """        if (_video == null) ...[
          SizedBox(height: 10),
          _mediaActionButton(
            icon: Icons.movie_creation_rounded,
            label: activeStudio == null ? 'PHOTO → VIDEO' : 'STUDIO SELECTED',
            sublabel: _photos.length < 3
                ? 'Add 3 photos first'
                : activeStudio == null
                ? 'Pan · zoom · cuts · sound'
                : 'Tap to preview or change',
            onTap: _openStudio,
          ),
        ],
"""
replace_once(ai, ai_tip, ai_tip_new)

print('Studio integration patch applied successfully.')
