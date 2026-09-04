from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    s = p.read_text()
    if new in s:
        return
    if old not in s:
        raise SystemExit(f"{label}: anchor not found in {path}")
    p.write_text(s.replace(old, new, 1))


# 1) Restore the real editable AI search bar. GlowSearchBar only renders the
# voice/microphone controls when it receives a TextEditingController.
shell = "lib/src/features/dashboard/presentation/screens/dashboard_shell.dart"
replace_once(
    shell,
    "import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';\n"
    "import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';\n",
    "import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';\n",
    "duplicate session import",
)
replace_once(
    shell,
    "  String? _lastLocation;\n  double _eventsSwipeOffset = 0;\n",
    "  String? _lastLocation;\n"
    "  double _eventsSwipeOffset = 0;\n"
    "  final TextEditingController _dashboardSearchController =\n"
    "      TextEditingController();\n",
    "dashboard search controller field",
)
replace_once(
    shell,
    "  void dispose() {\n"
    "    ref.read(chromeVisibilityProvider.notifier).suppressExplicitHide(false);\n"
    "    ref.read(sessionGamificationProvider).stopTracking();\n"
    "    super.dispose();\n"
    "  }\n",
    "  void dispose() {\n"
    "    _dashboardSearchController.dispose();\n"
    "    ref.read(chromeVisibilityProvider.notifier).suppressExplicitHide(false);\n"
    "    ref.read(sessionGamificationProvider).stopTracking();\n"
    "    super.dispose();\n"
    "  }\n",
    "dashboard search controller dispose",
)
replace_once(
    shell,
    "                    searchBar: GlowSearchBar(hint: 'What are you looking for?'),\n",
    "                    searchBar: GlowSearchBar(\n"
    "                      controller: _dashboardSearchController,\n"
    "                      hint: 'What are you looking for?',\n"
    "                    ),\n",
    "dashboard editable AI search bar",
)

# 2) Web/PWA must prefer the promoted fast-start MP4. The backend pipeline
# promotes video_url to its processed delivery MP4 and keeps video_original_url
# as the immutable raw upload for recovery.
listing = "lib/src/features/swipes/domain/models/listing.dart"
replace_once(
    listing,
    "    // Web/PWA intentionally mirrors Admin Events: play the exact raw file that\n"
    "    // was uploaded to Supabase. This removes both browser-side re-recording and\n"
    "    // processed-rendition cadence as variables from the Properties canary.\n"
    "    if (kIsWeb) {\n"
    "      if (original != null && original.isNotEmpty) return original;\n"
    "      if (mp4 != null && mp4.isNotEmpty) return mp4;\n"
    "      return hls == null || hls.isEmpty ? null : hls;\n"
    "    }\n",
    "    // The video pipeline promotes `video_url` to the delivery MP4 when it is\n"
    "    // ready and keeps `video_original_url` as the immutable raw upload. Web/PWA\n"
    "    // must prefer the promoted fast-start MP4; preferring the raw file made a\n"
    "    // clip look fine to its uploader but cold/stuttery on another device.\n"
    "    if (kIsWeb) {\n"
    "      if (mp4 != null && mp4.isNotEmpty) return mp4;\n"
    "      if (original != null && original.isNotEmpty) return original;\n"
    "      return hls == null || hls.isEmpty ? null : hls;\n"
    "    }\n",
    "web processed video preference",
)

# 3) Keep preview identity listing-scoped. Two different listing records are
# allowed to point at the exact same physical movie URL.
bento = "lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart"
replace_once(
    bento,
    "    final seenPreviewUrls = <String>{};\n"
    "    final sourceListingIds = <String, String>{};\n"
    "    final sourceImageListingIds = <String, String>{};\n"
    "    final videoPosterUrls = <String, String>{};\n"
    "    final listingPreviewMedia = <String>[];\n",
    "    final seenPreviewListingIds = <String>{};\n"
    "    final sourceListingIds = <String, String>{};\n"
    "    final sourceImageListingIds = <String, String>{};\n"
    "    final videoPosterUrls = <String, String>{};\n"
    "    final listingPreviewMedia = <String>[];\n"
    "    final listingPreviewListingIds = <String?>[];\n"
    "    final listingPreviewPosterUrls = <String?>[];\n",
    "listing-scoped preview declarations",
)
replace_once(
    bento,
    "      final source = video.isNotEmpty ? video : image;\n"
    "      if (source.isEmpty || !seenPreviewUrls.add(source)) continue;\n"
    "      listingPreviewMedia.add(source);\n"
    "      if (video.isNotEmpty) {\n"
    "        sourceListingIds[video] = listing.id;\n"
    "        if (image.isNotEmpty) videoPosterUrls[video] = image;\n"
    "      } else {\n"
    "        sourceImageListingIds[source] = listing.id;\n"
    "      }\n",
    "      final source = video.isNotEmpty ? video : image;\n"
    "      // Never dedupe by the media URL. Listing A and Listing B may\n"
    "      // intentionally reference the same physical movie.\n"
    "      if (source.isEmpty ||\n"
    "          listing.id.isEmpty ||\n"
    "          !seenPreviewListingIds.add(listing.id)) {\n"
    "        continue;\n"
    "      }\n"
    "      listingPreviewMedia.add(source);\n"
    "      listingPreviewListingIds.add(listing.id);\n"
    "      listingPreviewPosterUrls.add(\n"
    "        video.isNotEmpty && image.isNotEmpty ? image : null,\n"
    "      );\n"
    "      if (video.isNotEmpty) {\n"
    "        // Legacy URL maps cannot represent duplicate URLs. Keep only the\n"
    "        // first entry there; Properties consumes the index-aligned ID.\n"
    "        sourceListingIds.putIfAbsent(video, () => listing.id);\n"
    "        if (image.isNotEmpty) {\n"
    "          videoPosterUrls.putIfAbsent(video, () => image);\n"
    "        }\n"
    "      } else {\n"
    "        sourceImageListingIds.putIfAbsent(source, () => listing.id);\n"
    "      }\n",
    "listing-scoped preview loop",
)
replace_once(
    bento,
    "                PropertyTeaserCard(\n"
    "                  media: liveListingMedia,\n"
    "                  sourceListingIds: sourceListingIds,\n"
    "                  sourceImageListingIds: sourceImageListingIds,\n"
    "                  videoPosterUrls: videoPosterUrls,\n",
    "                PropertyTeaserCard(\n"
    "                  media: liveListingMedia,\n"
    "                  sourceListingIdsByIndex: listingPreviewListingIds,\n"
    "                  videoPosterUrlsByIndex: listingPreviewPosterUrls,\n"
    "                  sourceListingIds: sourceListingIds,\n"
    "                  sourceImageListingIds: sourceImageListingIds,\n"
    "                  videoPosterUrls: videoPosterUrls,\n",
    "Property listing-index handoff",
)

# 4) Property teaser: carry exact listing identity by index and mirror Events'
# prepare-before-swap controller lifecycle.
prop = "lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart"
replace_once(
    prop,
    "    required this.media,\n"
    "    required this.sourceListingIds,\n"
    "    required this.sourceImageListingIds,\n"
    "    required this.videoPosterUrls,\n",
    "    required this.media,\n"
    "    required this.sourceListingIdsByIndex,\n"
    "    required this.videoPosterUrlsByIndex,\n"
    "    required this.sourceListingIds,\n"
    "    required this.sourceImageListingIds,\n"
    "    required this.videoPosterUrls,\n",
    "Property constructor index identity",
)
replace_once(
    prop,
    "  final List<String> media;\n"
    "  final Map<String, String> sourceListingIds;\n"
    "  final Map<String, String> sourceImageListingIds;\n"
    "  final Map<String, String> videoPosterUrls;\n",
    "  final List<String> media;\n"
    "  final List<String?> sourceListingIdsByIndex;\n"
    "  final List<String?> videoPosterUrlsByIndex;\n"
    "  final Map<String, String> sourceListingIds;\n"
    "  final Map<String, String> sourceImageListingIds;\n"
    "  final Map<String, String> videoPosterUrls;\n",
    "Property index identity fields",
)
replace_once(
    prop,
    "    if (listEquals(oldWidget.media, widget.media)) return;\n",
    "    if (listEquals(oldWidget.media, widget.media) &&\n"
    "        listEquals(\n"
    "          oldWidget.sourceListingIdsByIndex,\n"
    "          widget.sourceListingIdsByIndex,\n"
    "        ) &&\n"
    "        listEquals(\n"
    "          oldWidget.videoPosterUrlsByIndex,\n"
    "          widget.videoPosterUrlsByIndex,\n"
    "        )) {\n"
    "      return;\n"
    "    }\n",
    "Property update identity comparison",
)
replace_once(
    prop,
    "  String? _listingIdFor(String url) {\n"
    "    final normalized = url.trim();\n"
    "    return widget.sourceListingIds[normalized] ??\n"
    "        widget.sourceImageListingIds[normalized];\n"
    "  }\n\n"
    "  String? _posterFor(String url) {\n"
    "    final poster = widget.videoPosterUrls[url.trim()]?.trim();\n"
    "    return poster == null || poster.isEmpty ? null : poster;\n"
    "  }\n",
    "  String? _listingIdForIndex(int index, String url) {\n"
    "    if (index >= 0 && index < widget.sourceListingIdsByIndex.length) {\n"
    "      final direct = widget.sourceListingIdsByIndex[index]?.trim();\n"
    "      if (direct != null && direct.isNotEmpty) return direct;\n"
    "    }\n"
    "    final normalized = url.trim();\n"
    "    return widget.sourceListingIds[normalized] ??\n"
    "        widget.sourceImageListingIds[normalized];\n"
    "  }\n\n"
    "  String? _posterForIndex(int index, String url) {\n"
    "    if (index >= 0 && index < widget.videoPosterUrlsByIndex.length) {\n"
    "      final direct = widget.videoPosterUrlsByIndex[index]?.trim();\n"
    "      if (direct != null && direct.isNotEmpty) return direct;\n"
    "    }\n"
    "    final poster = widget.videoPosterUrls[url.trim()]?.trim();\n"
    "    return poster == null || poster.isEmpty ? null : poster;\n"
    "  }\n",
    "Property exact listing/poster lookup",
)
replace_once(
    prop,
    "      await controller.initialize();\n"
    "      await controller.setLooping(false);\n"
    "      await controller.setVolume(0);\n",
    "      await controller.initialize();\n"
    "      await controller.setLooping(false);\n"
    "      await controller.setPlaybackSpeed(1.0);\n"
    "      await controller.setVolume(0);\n",
    "Property playback speed normalization",
)
replace_once(
    prop,
    "    if (_preloaded != null && _preloadedIndex == target) return;\n"
    "    final prepared = await _prepare(url);\n",
    "    if (_current != null &&\n"
    "        _currentUrl == url &&\n"
    "        _current!.value.isInitialized) {\n"
    "      final old = _preloaded;\n"
    "      _preloaded = null;\n"
    "      _preloadedIndex = null;\n"
    "      if (old != null) unawaited(old.dispose());\n"
    "      return;\n"
    "    }\n"
    "    if (_preloaded != null && _preloadedIndex == target) return;\n"
    "    final prepared = await _prepare(url);\n",
    "Property duplicate-url preload reuse",
)

p = Path(prop)
s = p.read_text()
old_method = (
    "  Future<void> _replaceForIndex(int target) async {\n"
    "    await _pausePlayback(resumeEvents: true);\n"
    "    final old = _current;\n"
    "    old?.removeListener(_onPlayerTick);\n"
    "    _current = null;\n"
    "    _currentUrl = null;\n"
    "    _completionQueued = false;\n"
    "    if (old != null) unawaited(old.dispose());\n\n"
    "    if (!mounted || widget.media.isEmpty) return;\n"
    "    _index = target % widget.media.length;\n"
    "    if (mounted) setState(() {});\n"
    "    await _ensureCurrentPrepared();\n"
    "    unawaited(_preloadNext());\n"
    "    _scheduleRotation();\n"
    "  }\n"
)
new_method = (
    "  Future<void> _replaceForIndex(int target) async {\n"
    "    if (!mounted || widget.media.isEmpty) return;\n"
    "    var nextIndex = target % widget.media.length;\n"
    "    if (nextIndex < 0) nextIndex += widget.media.length;\n\n"
    "    final nextUrl = widget.media[nextIndex].trim();\n"
    "    final previous = _current;\n"
    "    final previousUrl = _currentUrl;\n"
    "    final keepPlaying = _manualPlaying;\n"
    "    _rotateTimer?.cancel();\n\n"
    "    // Separate listings may intentionally share one media file. Change\n"
    "    // listing identity/index without reconnecting to that same URL.\n"
    "    if (previous != null &&\n"
    "        previous.value.isInitialized &&\n"
    "        previousUrl == nextUrl) {\n"
    "      _index = nextIndex;\n"
    "      _completionQueued = false;\n"
    "      try {\n"
    "        await previous.seekTo(Duration.zero);\n"
    "        if (keepPlaying) {\n"
    "          await previous.setVolume(0);\n"
    "          await _playWithWebFallback(previous);\n"
    "          if (_soundOn && (_mediaUnlocked || !kIsWeb)) {\n"
    "            await previous.setVolume(1);\n"
    "          }\n"
    "        }\n"
    "      } catch (_) {}\n"
    "      if (mounted) setState(() {});\n"
    "      unawaited(_preloadNext());\n"
    "      _scheduleRotation();\n"
    "      return;\n"
    "    }\n\n"
    "    // Match Events: prepare incoming video before releasing outgoing.\n"
    "    VideoPlayerController? prepared;\n"
    "    if (_isVideo(nextUrl)) {\n"
    "      if (_preloaded != null &&\n"
    "          _preloadedIndex == nextIndex &&\n"
    "          _preloaded!.value.isInitialized) {\n"
    "        prepared = _preloaded;\n"
    "        _preloaded = null;\n"
    "        _preloadedIndex = null;\n"
    "      } else {\n"
    "        prepared = await _prepare(nextUrl);\n"
    "      }\n"
    "      if (!mounted) {\n"
    "        await prepared?.dispose();\n"
    "        return;\n"
    "      }\n"
    "    }\n\n"
    "    previous?.removeListener(_onPlayerTick);\n"
    "    _index = nextIndex;\n"
    "    _current = prepared;\n"
    "    _currentUrl = prepared == null ? null : nextUrl;\n"
    "    _completionQueued = false;\n\n"
    "    if (prepared != null) {\n"
    "      prepared.addListener(_onPlayerTick);\n"
    "      if (keepPlaying) {\n"
    "        await prepared.setVolume(0);\n"
    "        await _playWithWebFallback(prepared);\n"
    "        if (_soundOn && (_mediaUnlocked || !kIsWeb)) {\n"
    "          await prepared.setVolume(1);\n"
    "        }\n"
    "        _manualPlaying = true;\n"
    "      } else {\n"
    "        _manualPlaying = false;\n"
    "      }\n"
    "    } else {\n"
    "      _manualPlaying = false;\n"
    "      resumeDashboardEventsPreviewAfterListing();\n"
    "    }\n\n"
    "    if (mounted) setState(() {});\n\n"
    "    if (previous != null && !identical(previous, prepared)) {\n"
    "      Future<void>.delayed(const Duration(milliseconds: 520), () async {\n"
    "        try {\n"
    "          await previous.setVolume(0);\n"
    "          await previous.pause();\n"
    "          await previous.dispose();\n"
    "        } catch (_) {}\n"
    "      });\n"
    "    }\n"
    "    unawaited(_preloadNext());\n"
    "    _scheduleRotation();\n"
    "  }\n"
)
if new_method not in s:
    if old_method not in s:
        raise SystemExit("Property event-style replacement method anchor not found")
    p.write_text(s.replace(old_method, new_method, 1))

replace_once(
    prop,
    "    final listingId = _listingIdFor(url);\n",
    "    final safeIndex = _index % widget.media.length;\n"
    "    final listingId = _listingIdForIndex(safeIndex, url);\n",
    "Property exact open listing ID",
)
replace_once(
    prop,
    "    final poster = video ? _posterFor(url) : null;\n",
    "    final poster = video ? _posterForIndex(safeIndex, url) : null;\n",
    "Property exact poster by listing index",
)

print("Focused Property video identity + AI mic patch applied")
