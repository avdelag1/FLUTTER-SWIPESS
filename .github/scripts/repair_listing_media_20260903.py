from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"missing patch target: {label}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Draft media: normalize picker MIME aliases accepted differently by browsers.
# ---------------------------------------------------------------------------
p = "lib/src/features/add/data/listing_draft_repository.dart"
s = read(p)
s = replace_once(
    s,
    """  static String _mimeType(XFile file) {\n    final explicit = file.mimeType?.trim();\n    if (explicit != null && explicit.isNotEmpty) return explicit;\n    final lower = file.name.toLowerCase();\n""",
    """  static String _mimeType(XFile file) {\n    final explicit = file.mimeType?.trim().toLowerCase();\n    if (explicit != null && explicit.isNotEmpty) {\n      if (explicit == 'image/jpg') return 'image/jpeg';\n      if (explicit == 'audio/x-m4a') return 'audio/mp4';\n      if (explicit == 'audio/x-wav') return 'audio/wav';\n      if (explicit == 'video/x-m4v') return 'video/mp4';\n      return explicit;\n    }\n    final lower = file.name.toLowerCase();\n""",
    "draft MIME aliases",
)
write(p, s)


# ---------------------------------------------------------------------------
# AI listing: don't run the same extraction twice before publishing.
# ---------------------------------------------------------------------------
p = "lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart"
s = read(p)
s = replace_once(
    s,
    """      var parsed = const <String, dynamic>{};\n      try {\n        final structuredPrompt = <String>[\n          'Description:\\n$originalDescription',\n          if (typedCity.isNotEmpty) 'User city: $typedCity',\n          if (typedPrice.isNotEmpty) 'User price: $typedPrice $_currency',\n        ].join('\\n');\n        parsed = await ref\n            .read(aiEdgeRepositoryProvider)\n            .extractListing(\n              category: _category,\n              prompt: structuredPrompt,\n              city: typedCity,\n              price: typedPrice,\n            )\n            .timeout(\n              const Duration(seconds: 8),\n              onTimeout: () => const <String, dynamic>{},\n            );\n      } catch (error) {\n        debugPrint('[AiListingBuilder] extractor fallback: $error');\n      }\n""",
    """      var parsed = Map<String, dynamic>.of(_aiPreview);\n      if (parsed.isEmpty) {\n        try {\n          final structuredPrompt = <String>[\n            'Description:\\n$originalDescription',\n            if (typedCity.isNotEmpty) 'User city: $typedCity',\n            if (typedPrice.isNotEmpty) 'User price: $typedPrice $_currency',\n          ].join('\\n');\n          parsed = await ref\n              .read(aiEdgeRepositoryProvider)\n              .extractListing(\n                category: _category,\n                prompt: structuredPrompt,\n                city: typedCity,\n                price: typedPrice,\n              )\n              .timeout(\n                const Duration(seconds: 5),\n                onTimeout: () => const <String, dynamic>{},\n              );\n        } catch (error) {\n          debugPrint('[AiListingBuilder] extractor fallback: $error');\n        }\n      }\n""",
    "reuse AI listing preview",
)
write(p, s)


# ---------------------------------------------------------------------------
# Publishing: photo moderation, video and soundtrack can upload concurrently.
# ---------------------------------------------------------------------------
p = "lib/src/features/add/presentation/providers/add_listing_provider.dart"
s = read(p)
s = replace_once(
    s,
    """      final ai = ref.read(aiEdgeRepositoryProvider);\n      final urls = await repo.uploadListingPhotos(\n        userId: user.id,\n        files: state.photos,\n        moderateImage: ai.assertImageSafe,\n      );\n      String? videoUrl;\n      final video = state.video;\n      if (video != null) {\n        videoUrl = await repo.uploadListingVideo(userId: user.id, file: video);\n      }\n      String? backgroundMusicUrl;\n      final backgroundMusic = state.backgroundMusic;\n      if (video != null && backgroundMusic != null) {\n        backgroundMusicUrl = await repo.uploadListingAudio(\n          userId: user.id,\n          file: backgroundMusic,\n        );\n      }\n""",
    """      final ai = ref.read(aiEdgeRepositoryProvider);\n      final video = state.video;\n      final backgroundMusic = state.backgroundMusic;\n\n      final photosFuture = repo.uploadListingPhotos(\n        userId: user.id,\n        files: state.photos,\n        moderateImage: ai.assertImageSafe,\n      );\n      final videoFuture = video == null\n          ? Future<String?>.value(null)\n          : repo\n                .uploadListingVideo(userId: user.id, file: video)\n                .then<String?>((url) => url);\n      final musicFuture = video == null || backgroundMusic == null\n          ? Future<String?>.value(null)\n          : repo.uploadListingAudio(userId: user.id, file: backgroundMusic);\n\n      final urls = await photosFuture;\n      final videoUrl = await videoFuture;\n      final backgroundMusicUrl = await musicFuture;\n""",
    "parallel listing media upload",
)
write(p, s)


# ---------------------------------------------------------------------------
# Discovery: don't block first paint on cache serialization.
# ---------------------------------------------------------------------------
p = "lib/src/features/swipes/data/market_swipe_repository.dart"
s = read(p)
if "import 'dart:async';" not in s:
    s = replace_once(s, "import 'dart:convert';\n", "import 'dart:async';\nimport 'dart:convert';\n", "market async import")
s = replace_once(
    s,
    """      rows = data;\n      await _saveCache(cacheKey, rows);\n""",
    """      rows = data;\n      unawaited(_saveCache(cacheKey, rows));\n""",
    "nonblocking discovery cache",
)
write(p, s)


# ---------------------------------------------------------------------------
# Dashboard preview: fetch only 8 cards/category. Full decks stay on demand.
# ---------------------------------------------------------------------------
p = "lib/src/features/swipes/presentation/providers/swipe_providers.dart"
s = read(p)
provider = """/// Lightweight dashboard preview feed. It intentionally avoids full deck\n/// filters and asks the server for only a handful of cards per category.\nfinal quickFilterPreviewListingsProvider =\n    FutureProvider.family<List<Listing>, String>((ref, category) async {\n  final user = ref.watch(currentUserProvider);\n  if (user == null) return const <Listing>[];\n  final discovery = ref.watch(discoveryLocationProvider);\n  final repository = ref.read(marketSwipeRepositoryProvider);\n  return repository.fetch(\n    category: category,\n    marketCity: discovery.city,\n    marketCountry: discovery.country,\n    limit: 8,\n  );\n});\n\n"""
anchor = "/// Starts fresh, account-scoped discovery requests as soon as a session is\n"
if "quickFilterPreviewListingsProvider" not in s:
    s = replace_once(s, anchor, provider + anchor, "light quick-filter provider")
s = replace_once(s, "    limit: 40,\n", "    limit: 24,\n", "smaller full deck")
s = replace_once(
    s,
    """  unawaited(\n    Future.wait<void>([\n      ref.read(swipeListingsProvider('property').future),\n      ref.read(swipeListingsProvider('services').future),\n      ref.read(swipeListingsProvider('yacht').future),\n      ref.read(swipeListingsProvider('motorcycle').future),\n      ref.read(swipeListingsProvider('bicycle').future),\n    ]).catchError((_) {}),\n  );\n""",
    """  // Avoid five simultaneous full-feed requests during app startup. Property\n  // is the most common first deck, so warm only it after the dashboard paints.\n  unawaited(\n    Future<void>.delayed(const Duration(milliseconds: 450), () async {\n      await ref.read(swipeListingsProvider('property').future);\n    }).catchError((_) {}),\n  );\n""",
    "staged discovery warmup",
)
write(p, s)


# ---------------------------------------------------------------------------
# Bento dashboard: preserve a poster image for every listing video.
# ---------------------------------------------------------------------------
p = "lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart"
s = read(p)
s = replace_once(
    s,
    """    final previewAsync = isListingPreviewQuickFilter\n        ? ref.watch(swipeListingsProvider(item.id))\n        : null;\n""",
    """    final previewAsync = isListingPreviewQuickFilter\n        ? ref.watch(quickFilterPreviewListingsProvider(item.id))\n        : null;\n""",
    "bento light preview provider",
)
s = replace_once(
    s,
    """    final sourceListingIds = <String, String>{};\n    final listingPreviewMedia = <String>[];\n""",
    """    final sourceListingIds = <String, String>{};\n    final videoPosterUrls = <String, String>{};\n    final listingPreviewMedia = <String>[];\n""",
    "bento poster map",
)
s = replace_once(
    s,
    """      listingPreviewMedia.add(source);\n      if (video.isNotEmpty) sourceListingIds[video] = listing.id;\n""",
    """      listingPreviewMedia.add(source);\n      if (video.isNotEmpty) {\n        sourceListingIds[video] = listing.id;\n        if (image.isNotEmpty) videoPosterUrls[video] = image;\n      }\n""",
    "associate video poster",
)
s = replace_once(
    s,
    """          sourceListingIds: sourceListingIds,\n          handoffCategoryId: isListingPreviewQuickFilter ? item.id : null,\n""",
    """          sourceListingIds: sourceListingIds,\n          videoPosterUrls: videoPosterUrls,\n          handoffCategoryId: isListingPreviewQuickFilter ? item.id : null,\n""",
    "pass poster map to card",
)
s = replace_once(
    s,
    """    this.sourceListingIds = const <String, String>{},\n    this.handoffCategoryId,\n""",
    """    this.sourceListingIds = const <String, String>{},\n    this.videoPosterUrls = const <String, String>{},\n    this.handoffCategoryId,\n""",
    "bento card poster constructor",
)
s = replace_once(
    s,
    """  final Map<String, String> sourceListingIds;\n  final String? handoffCategoryId;\n""",
    """  final Map<String, String> sourceListingIds;\n  final Map<String, String> videoPosterUrls;\n  final String? handoffCategoryId;\n""",
    "bento card poster field",
)
s = replace_once(
    s,
    """                  sourceListingIds: widget.sourceListingIds,\n                  handoffCategoryId: widget.handoffCategoryId,\n""",
    """                  sourceListingIds: widget.sourceListingIds,\n                  videoPosterUrls: widget.videoPosterUrls,\n                  handoffCategoryId: widget.handoffCategoryId,\n""",
    "pass poster to media",
)
write(p, s)


# ---------------------------------------------------------------------------
# Shared card clock: manual video pauses automatic card changes globally.
# ---------------------------------------------------------------------------
p = "lib/src/features/dashboard/presentation/providers/quick_filter_rotate_provider.dart"
s = read(p)
if "pauseForManualVideo" not in s:
    marker = "  void resumeStillWindow({required int slot, required int slotCount}) {\n"
    methods = """  void pauseForManualVideo({required int slot, required int slotCount}) {\n    final normalized = _normalizedSlot(slot, slotCount);\n    _heldForVideo = true;\n    _heldSlot = normalized;\n    _timer?.cancel();\n    _timer = null;\n  }\n\n  void resumeAfterManualVideo({required int slot, required int slotCount}) {\n    final normalized = _normalizedSlot(slot, slotCount);\n    if (!_heldForVideo || _heldSlot != normalized) return;\n    _heldForVideo = false;\n    _heldSlot = null;\n    _armStillWindow();\n  }\n\n"""
    s = replace_once(s, marker, methods + marker, "manual dashboard hold methods")
write(p, s)


# ---------------------------------------------------------------------------
# Non-Events quick-filter videos: poster first, manual Play only, portrait cover.
# Events use EventsTeaserCard and are intentionally unaffected.
# ---------------------------------------------------------------------------
p = "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart"
s = read(p)
s = replace_once(
    s,
    """    this.sourceListingIds = const <String, String>{},\n    this.handoffCategoryId,\n""",
    """    this.sourceListingIds = const <String, String>{},\n    this.videoPosterUrls = const <String, String>{},\n    this.handoffCategoryId,\n""",
    "media poster constructor",
)
s = replace_once(
    s,
    """  final Map<String, String> sourceListingIds;\n  final String? handoffCategoryId;\n""",
    """  final Map<String, String> sourceListingIds;\n  final Map<String, String> videoPosterUrls;\n  final String? handoffCategoryId;\n""",
    "media poster field",
)
s = replace_once(
    s,
    """  bool _userPaused = false;\n  bool _lastReportedPlaying = false;\n""",
    """  bool _userPaused = true;\n  bool _manualPlaybackStarted = false;\n  bool _lastReportedPlaying = false;\n""",
    "manual video state",
)
s = replace_once(
    s,
    """  bool get _canPlay =>\n      _routeActive && _appActive && _videoEnabled && _ownsRotateTurn;\n""",
    """  bool get _canPlay =>\n      _routeActive &&\n      _appActive &&\n      _videoEnabled &&\n      _manualPlaybackStarted &&\n      !_userPaused;\n""",
    "manual play gate",
)

# Replace play and sound controls as one block.
pattern = re.compile(
    r"  void _togglePlayPause\(\) \{.*?\n  void _toggleSound\(\) \{.*?\n  void _scheduleVisibilityCheck\(\) \{",
    re.S,
)
replacement = """  void _togglePlayPause() {\n    AppHaptics.selection();\n\n    final player = _video;\n    if (player != null &&\n        player.value.isInitialized &&\n        player.value.isPlaying) {\n      unawaited(player.pause());\n      setState(() {\n        _userPaused = true;\n        _manualPlaybackStarted = false;\n      });\n      ref.read(quickFilterRotateTickProvider.notifier).resumeAfterManualVideo(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n      _VideoPlaybackCoordinator.release(this);\n      return;\n    }\n\n    setState(() {\n      _videoPreviewEnabled = true;\n      _userPaused = false;\n      _manualPlaybackStarted = true;\n    });\n    ref.read(quickFilterRotateTickProvider.notifier).pauseForManualVideo(\n          slot: widget.rotateSlot,\n          slotCount: _rotateSlotCount,\n        );\n    unawaited(_syncVideo(autoPlay: true));\n    _scheduleVisibilityCheck();\n  }\n\n  void _toggleSound() {\n    AppHaptics.selection();\n    unlockDeckMedia();\n    final nextSoundOn = !ref.read(deckSoundOnProvider);\n    ref.read(deckSoundOnProvider.notifier).setSoundOn(nextSoundOn);\n    _onSoundChanged(nextSoundOn);\n  }\n\n  void _scheduleVisibilityCheck() {"""
s, n = pattern.subn(replacement, s, count=1)
if n != 1:
    raise RuntimeError("missing patch target: quick-filter manual controls")

# Visibility no longer preloads/autoplays video.
pattern = re.compile(
    r"  void _updateVisibilityAndPlayback\(\) \{.*?\n  void _pauseForCoordinator\(\{bool releaseOwnership = true\}\) \{.*?\n  String\? _listingIdForUrl",
    re.S,
)
replacement = """  void _updateVisibilityAndPlayback() {\n    if (!_routeActive || !_appActive) {\n      _visibleFraction = 0;\n      _video?.setVolume(0);\n      _pauseForCoordinator();\n      return;\n    }\n    final render = context.findRenderObject();\n    if (render is! RenderBox || !render.hasSize) return;\n\n    final top = render.localToGlobal(Offset.zero).dy;\n    final bottom = top + render.size.height;\n    final screenHeight = MediaQuery.sizeOf(context).height;\n    final visibleHeight = (math.min(bottom, screenHeight) - math.max(top, 0.0))\n        .clamp(0.0, render.size.height);\n    _visibleFraction = render.size.height <= 0\n        ? 0.0\n        : visibleHeight / render.size.height;\n\n    if (_sources.isEmpty) return;\n    final current = _sources[_index % _sources.length];\n    if (!_videoEnabled || !isQuickFilterVideoUrl(current)) {\n      _pauseForCoordinator();\n      return;\n    }\n\n    // Listing videos are manual-only. Keep the poster visible and avoid any\n    // network video initialization until the user explicitly presses Play.\n    if (!_manualPlaybackStarted || _userPaused) {\n      _pauseForCoordinator();\n      return;\n    }\n\n    if (_visibleFraction >= 0.50) {\n      if (_VideoPlaybackCoordinator.activate(this, _visibleFraction)) {\n        unawaited(_playIfReady());\n      }\n    } else {\n      _pauseForCoordinator();\n    }\n  }\n\n  void _pauseForCoordinator({bool releaseOwnership = true}) {\n    final player = _video;\n    if (player != null && player.value.isInitialized) {\n      unawaited(player.setVolume(0));\n      if (player.value.isPlaying) unawaited(player.pause());\n    }\n    if (releaseOwnership) _VideoPlaybackCoordinator.release(this);\n  }\n\n  String? _listingIdForUrl"""
s, n = pattern.subn(replacement, s, count=1)
if n != 1:
    raise RuntimeError("missing patch target: quick-filter visibility")

# Handoff releases the manual global hold.
s = replace_once(
    s,
    """    _video = null;\n    _boundVideoUrl = null;\n    _binding = false;\n    _userPaused = false;\n\n    return SwipeDeckMediaHandoffData(\n""",
    """    _video = null;\n    _boundVideoUrl = null;\n    _binding = false;\n    _userPaused = true;\n    _manualPlaybackStarted = false;\n    ref.read(quickFilterRotateTickProvider.notifier).resumeAfterManualVideo(\n          slot: widget.rotateSlot,\n          slotCount: _rotateSlotCount,\n        );\n\n    return SwipeDeckMediaHandoffData(\n""",
    "handoff manual hold release",
)

# Playing a manually requested movie pauses the shared rotation regardless of slot.
s = replace_once(
    s,
    """    ref.read(quickFilterRotateTickProvider.notifier).holdForVideo(\n          slot: widget.rotateSlot,\n          slotCount: _rotateSlotCount,\n        );\n""",
    """    ref.read(quickFilterRotateTickProvider.notifier).pauseForManualVideo(\n          slot: widget.rotateSlot,\n          slotCount: _rotateSlotCount,\n        );\n""",
    "manual play global hold",
)

# Ended manual video resumes the 7.6s shared still clock instead of advancing itself.
s = replace_once(
    s,
    """    if (ended && _ownsRotateTurn && !_reportedVideoTurnComplete) {\n      _reportedVideoTurnComplete = true;\n      ref.read(quickFilterRotateTickProvider.notifier).completeVideoTurn(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n    }\n""",
    """    if (ended && _manualPlaybackStarted && !_reportedVideoTurnComplete) {\n      _reportedVideoTurnComplete = true;\n      _manualPlaybackStarted = false;\n      _userPaused = true;\n      ref.read(quickFilterRotateTickProvider.notifier).resumeAfterManualVideo(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n      _VideoPlaybackCoordinator.release(this);\n    }\n""",
    "manual video end",
)

# Media changes reset to off/manual state.
s = replace_once(
    s,
    """    _binding = false;\n    _userPaused = false;\n    _reportedVideoTurnComplete = false;\n""",
    """    _binding = false;\n    _userPaused = true;\n    _manualPlaybackStarted = false;\n    _reportedVideoTurnComplete = false;\n""",
    "dispose manual state",
)
s = replace_once(
    s,
    """      _userPaused = false;\n      _reportedVideoTurnComplete = false;\n""",
    """      _userPaused = true;\n      _manualPlaybackStarted = false;\n      _reportedVideoTurnComplete = false;\n""",
    "advance manual state",
)

# On decode error, release manual hold and return to poster.
s = replace_once(
    s,
    """      if (_ownsRotateTurn) {\n        ref.read(quickFilterRotateTickProvider.notifier).resumeStillWindow(\n              slot: widget.rotateSlot,\n              slotCount: _rotateSlotCount,\n            );\n      }\n""",
    """      _manualPlaybackStarted = false;\n      _userPaused = true;\n      ref.read(quickFilterRotateTickProvider.notifier).resumeAfterManualVideo(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n""",
    "video decode fallback",
)

# Poster helper.
if "String? _posterForVideo" not in s:
    s = replace_once(
        s,
        "  String? _fallbackStillUrl() {\n",
        """  String? _posterForVideo(String url) {\n    final normalized = url.trim();\n    for (final entry in widget.videoPosterUrls.entries) {\n      if (entry.key.trim() == normalized && entry.value.trim().isNotEmpty) {\n        return entry.value.trim();\n      }\n    }\n    return null;\n  }\n\n  String? _fallbackStillUrl() {\n""",
        "video poster helper",
    )

# Build video with portrait cover crop. Before Play, show its own listing image poster.
pattern = re.compile(r"  Widget _buildMedia\(String url\) \{.*?\n  @override\n  Widget build", re.S)
replacement = """  Widget _buildMedia(String url) {\n    if (isQuickFilterVideoUrl(url)) {\n      if (!_videoEnabled) {\n        final fallback = _posterForVideo(url) ?? _fallbackStillUrl();\n        if (fallback != null) return _buildStill(fallback);\n        return const ColoredBox(color: Color(0xFF15171C));\n      }\n\n      final player = _video;\n      if (player != null &&\n          player.value.isInitialized &&\n          _boundVideoUrl == url) {\n        final size = player.value.size;\n        if (size.width > 0 && size.height > 0) {\n          return ClipRect(\n            child: SizedBox.expand(\n              child: FittedBox(\n                fit: BoxFit.cover,\n                alignment: Alignment.center,\n                clipBehavior: Clip.hardEdge,\n                child: SizedBox(\n                  width: size.width,\n                  height: size.height,\n                  child: VideoPlayer(player),\n                ),\n              ),\n            ),\n          );\n        }\n      }\n\n      final poster = _posterForVideo(url) ?? _fallbackStillUrl();\n      if (poster != null) return _buildStill(poster);\n      return const ColoredBox(color: Color(0xFF15171C));\n    }\n    return _buildStill(url);\n  }\n\n  @override\n  Widget build"""
s, n = pattern.subn(replacement, s, count=1)
if n != 1:
    raise RuntimeError("missing patch target: portrait video builder")

# Rotation changes one card per period but never starts a video.
pattern = re.compile(
    r"      // On each round, only the card whose turn just started changes listing\..*?\n    \}\);",
    re.S,
)
replacement = """      // On each round only this card changes listing. Video sources stay on\n      // their static poster until the user explicitly presses Play.\n      if (prev != null) _advance(1);\n    });"""
s, n = pattern.subn(replacement, s, count=1)
if n != 1:
    raise RuntimeError("missing patch target: remove rotation autoplay")
write(p, s)


# ---------------------------------------------------------------------------
# Video editor: cap expensive thumbnails and batch rebuilds.
# ---------------------------------------------------------------------------
p = "lib/src/features/camera/presentation/screens/video_cropper_screen_v2.dart"
s = read(p)
pattern = re.compile(r"  Future<void> _loadThumbs\(\) async \{.*?\n  void _tick\(\) \{", re.S)
replacement = """  Future<void> _loadThumbs() async {\n    if (_duration <= 0) return;\n    final count = math.max(1, math.min(24, (_duration / 5).ceil())).toInt();\n    if (!mounted) return;\n    final thumbs = List<Uint8List?>.filled(count, null);\n    setState(() => _thumbs = List<Uint8List?>.from(thumbs));\n\n    for (var start = 0; start < count; start += 4) {\n      if (!mounted) return;\n      final end = math.min(count, start + 4);\n      await Future.wait<void>([\n        for (var i = start; i < end; i++)\n          () async {\n            try {\n              final sample = count == 1\n                  ? _duration / 2\n                  : (_duration * i / (count - 1)).clamp(\n                      0.0,\n                      math.max(0.0, _duration - .05),\n                    );\n              thumbs[i] = await VideoThumbnail.thumbnailData(\n                video: widget.file.path,\n                imageFormat: ImageFormat.JPEG,\n                maxWidth: 144,\n                quality: 34,\n                timeMs: (sample * 1000).round(),\n              );\n            } catch (_) {}\n          }(),\n      ]);\n      if (mounted) setState(() => _thumbs = List<Uint8List?>.from(thumbs));\n    }\n  }\n\n  void _tick() {"""
s, n = pattern.subn(replacement, s, count=1)
if n != 1:
    raise RuntimeError("missing patch target: video thumbnail batching")
write(p, s)

print("listing media repair applied")
