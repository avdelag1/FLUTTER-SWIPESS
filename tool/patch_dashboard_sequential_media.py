from pathlib import Path

root = Path('.')

# 1) Central round-robin clock: Properties starts first. Still turns last 7.6s;
# visible video turns pause the clock until the movie actually finishes.
rotate = root / 'lib/src/features/dashboard/presentation/providers/quick_filter_rotate_provider.dart'
rotate.write_text("""import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One shared dashboard media clock.
///
/// Properties owns slot 0, then the remaining non-Events quick filters take
/// turns one-by-one. A still gets a calm 7.6 second window. A visible listing
/// video can hold its turn until playback reaches the end, so another card does
/// not change three seconds later while the movie is still running.
class QuickFilterRotateTicker extends Notifier<int> {
  static const period = Duration(milliseconds: 7600);
  Timer? _timer;
  bool _heldForVideo = false;
  int? _heldSlot;

  @override
  int build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    _armStillWindow();
    return 0;
  }

  void _armStillWindow() {
    _timer?.cancel();
    if (_heldForVideo) return;
    _timer = Timer(period, _advance);
  }

  void _advance() {
    if (_heldForVideo) return;
    state = state + 1;
    _armStillWindow();
  }

  int _normalizedSlot(int slot, int slotCount) {
    final count = slotCount.clamp(1, 64);
    final normalized = slot % count;
    return normalized < 0 ? normalized + count : normalized;
  }

  bool isTurn({required int slot, required int slotCount}) {
    final count = slotCount.clamp(1, 64);
    return state % count == _normalizedSlot(slot, count);
  }

  void holdForVideo({required int slot, required int slotCount}) {
    if (!isTurn(slot: slot, slotCount: slotCount)) return;
    final normalized = _normalizedSlot(slot, slotCount);
    if (_heldForVideo && _heldSlot == normalized) return;
    _heldForVideo = true;
    _heldSlot = normalized;
    _timer?.cancel();
    _timer = null;
  }

  void completeVideoTurn({required int slot, required int slotCount}) {
    if (!isTurn(slot: slot, slotCount: slotCount)) return;
    final normalized = _normalizedSlot(slot, slotCount);
    if (!_heldForVideo || _heldSlot != normalized) return;
    _heldForVideo = false;
    _heldSlot = null;
    state = state + 1;
    _armStillWindow();
  }

  void resumeStillWindow({required int slot, required int slotCount}) {
    if (!isTurn(slot: slot, slotCount: slotCount)) return;
    _heldForVideo = false;
    _heldSlot = null;
    _armStillWindow();
  }
}

final quickFilterRotateTickProvider =
    NotifierProvider<QuickFilterRotateTicker, int>(QuickFilterRotateTicker.new);
""")

# 2) Make QuickFilterMedia obey the shared turn and finish videos before the
# next card advances.
media = root / 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
text = media.read_text()

old = """  bool _lastReportedPlaying = false;\n  double _visibleFraction = 0;"""
new = """  bool _lastReportedPlaying = false;\n  bool _reportedVideoTurnComplete = false;\n  double _visibleFraction = 0;"""
assert old in text
text = text.replace(old, new, 1)

old = """  bool get _videoEnabled => widget.enableVideo && _videoPreviewEnabled;\n  bool get _canPlay => _routeActive && _appActive && _videoEnabled;\n  bool get _hasVideo => _pool.any(isQuickFilterVideoUrl);"""
new = """  bool get _videoEnabled => widget.enableVideo && _videoPreviewEnabled;\n  bool get _canPlay =>\n      _routeActive && _appActive && _videoEnabled && _ownsRotateTurn;\n  bool get _hasVideo => _pool.any(isQuickFilterVideoUrl);\n\n  int get _rotateSlotCount => widget.slotCount.clamp(1, 64);\n\n  bool get _ownsRotateTurn {\n    final tick = ref.read(quickFilterRotateTickProvider);\n    final normalizedSlot = widget.rotateSlot % _rotateSlotCount;\n    return tick % _rotateSlotCount ==\n        (normalizedSlot < 0 ? normalizedSlot + _rotateSlotCount : normalizedSlot);\n  }"""
assert old in text
text = text.replace(old, new, 1)

old = """    if (!_videoEnabled || !isQuickFilterVideoUrl(current)) {\n      _pauseForCoordinator();\n      return;\n    }\n\n    if (fraction >= 0.15 && _video == null && !_binding) {\n      _syncVideo(autoPlay: false);\n    }\n\n    if (fraction >= 0.50) {\n      if (_VideoPlaybackCoordinator.activate(this, fraction)) {\n        unawaited(_playIfReady());\n      } else {\n        _pauseForCoordinator();\n      }\n    } else {\n      _pauseForCoordinator();\n    }"""
new = """    if (!_videoEnabled || !isQuickFilterVideoUrl(current)) {\n      _pauseForCoordinator();\n      return;\n    }\n\n    if (fraction >= 0.15 && _video == null && !_binding) {\n      _syncVideo(autoPlay: false);\n    }\n\n    // A listing video is allowed to move only during this card's shared turn.\n    // Other video cards stay decoded/frozen instead of all animating together.\n    if (!_ownsRotateTurn) {\n      _pauseForCoordinator();\n      return;\n    }\n\n    if (fraction >= 0.50) {\n      ref.read(quickFilterRotateTickProvider.notifier).holdForVideo(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n      if (_VideoPlaybackCoordinator.activate(this, fraction)) {\n        unawaited(_playIfReady());\n      } else {\n        _pauseForCoordinator(releaseOwnership: false);\n      }\n    } else {\n      _pauseForCoordinator();\n    }"""
assert old in text
text = text.replace(old, new, 1)

old = """  Future<void> _playIfReady() async {\n    if (!_canPlay || _userPaused || _visibleFraction < 0.50) return;"""
new = """  Future<void> _playIfReady() async {\n    if (!_canPlay || _userPaused || _visibleFraction < 0.50) return;\n\n    ref.read(quickFilterRotateTickProvider.notifier).holdForVideo(\n          slot: widget.rotateSlot,\n          slotCount: _rotateSlotCount,\n        );"""
assert old in text
text = text.replace(old, new, 1)

old = """  void _onPlayerTick() {\n    final playing = _video?.value.isPlaying ?? false;\n    if (playing == _lastReportedPlaying || !mounted) return;\n    _lastReportedPlaying = playing;\n    setState(() {});\n  }"""
new = """  void _onPlayerTick() {\n    final player = _video;\n    if (player == null || !mounted) return;\n\n    final value = player.value;\n    final durationMs = value.duration.inMilliseconds;\n    final positionMs = value.position.inMilliseconds;\n    final ended =\n        durationMs > 0 && positionMs >= durationMs - 140 && !value.isPlaying;\n\n    if (ended && _ownsRotateTurn && !_reportedVideoTurnComplete) {\n      _reportedVideoTurnComplete = true;\n      ref.read(quickFilterRotateTickProvider.notifier).completeVideoTurn(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n    }\n\n    final playing = value.isPlaying;\n    if (playing == _lastReportedPlaying) return;\n    _lastReportedPlaying = playing;\n    setState(() {});\n  }"""
assert old in text
text = text.replace(old, new, 1)

old = """    _binding = false;\n    _userPaused = false;\n  }\n\n  Widget _mediaControlButton"""
new = """    _binding = false;\n    _userPaused = false;\n    _reportedVideoTurnComplete = false;\n  }\n\n  Widget _mediaControlButton"""
assert old in text
text = text.replace(old, new, 1)

old = """      _index = (_index + delta) % _sources.length;\n      if (_index < 0) _index += _sources.length;\n      _userPaused = false;"""
new = """      _index = (_index + delta) % _sources.length;\n      if (_index < 0) _index += _sources.length;\n      _userPaused = false;\n      _reportedVideoTurnComplete = false;"""
assert old in text
text = text.replace(old, new, 1)

old = """      await next.setLooping(true);\n      await next.setVolume(0);"""
new = """      // Dashboard listing previews play once. Their real end advances the\n      // shared card sequence; looping would prevent the next card from moving.\n      await next.setLooping(false);\n      await next.setVolume(0);"""
assert old in text
text = text.replace(old, new, 1)

old = """    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {\n      if (!_routeActive || _visibleFraction >= 0.50) return;\n      final slots = widget.slotCount.clamp(1, 64);\n      if (next % slots == widget.rotateSlot % slots) {\n        _advance(1);\n      }\n    });"""
new = """    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {\n      if (!_routeActive) return;\n      final slots = _rotateSlotCount;\n      final normalizedSlot = widget.rotateSlot % slots;\n      final target = normalizedSlot < 0 ? normalizedSlot + slots : normalizedSlot;\n      if (next % slots != target) return;\n\n      // On each round, only the card whose turn just started changes listing.\n      // Properties is slot 0, then each remaining dashboard card follows.\n      if (prev != null) _advance(1);\n\n      if (_sources.isEmpty) return;\n      final now = _sources[_index % _sources.length];\n      if (isQuickFilterVideoUrl(now) && _visibleFraction >= 0.50) {\n        ref.read(quickFilterRotateTickProvider.notifier).holdForVideo(\n              slot: widget.rotateSlot,\n              slotCount: slots,\n            );\n        _scheduleVisibilityCheck();\n      } else {\n        ref.read(quickFilterRotateTickProvider.notifier).resumeStillWindow(\n              slot: widget.rotateSlot,\n              slotCount: slots,\n            );\n      }\n    });"""
assert old in text
text = text.replace(old, new, 1)
media.write_text(text)

# 3) Reconnect each listing's video URL to its dashboard category and remove the
# independent per-card random timers.
bento = root / 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
text = bento.read_text()

old = """    // Events are the only dashboard quick filter that auto-plays video.\n    // Every other listing category uses a portrait-cropped still preview and\n    // rotates through real listings instead of running several videos at once."""
new = """    // Events keeps its continuous live teaser. Listing quick filters use the\n    // real media from each listing: video when that listing has one, otherwise\n    // its cover photo. A shared round-robin clock lets only one non-Events card\n    // move at a time."""
assert old in text
text = text.replace(old, new, 1)

old = """    final seenPreviewUrls = <String>{};\n    final listingPreviewMedia = previewListings\n        .map((listing) => listing.primaryImage?.trim())\n        .whereType<String>()\n        .where((url) => url.isNotEmpty && seenPreviewUrls.add(url))\n        .toList(growable: false);"""
new = """    final seenPreviewUrls = <String>{};\n    final sourceListingIds = <String, String>{};\n    final listingPreviewMedia = <String>[];\n\n    // Premium/video listings lead the category preview. Each listing contributes\n    // exactly one dashboard source: its video if present, otherwise its cover.\n    // That prevents a video listing from being silently replaced by its photo.\n    final orderedPreviewListings = <Listing>[\n      ...previewListings.where((listing) => (listing.videoUrl ?? '').trim().isNotEmpty),\n      ...previewListings.where((listing) => (listing.videoUrl ?? '').trim().isEmpty),\n    ];\n    for (final listing in orderedPreviewListings) {\n      final video = (listing.videoUrl ?? '').trim();\n      final image = listing.primaryImage?.trim() ?? '';\n      final source = video.isNotEmpty ? video : image;\n      if (source.isEmpty || !seenPreviewUrls.add(source)) continue;\n      listingPreviewMedia.add(source);\n      if (video.isNotEmpty) sourceListingIds[video] = listing.id;\n    }"""
assert old in text
text = text.replace(old, new, 1)

old = """          stagger: Duration(seconds: int.parse(item.delaySeconds)),\n          isLight: isLight,\n          enableVideo: false,\n          onTap: () {"""
new = """          stagger: Duration(seconds: int.parse(item.delaySeconds)),\n          isLight: isLight,\n          enableVideo: isListingPreviewQuickFilter,\n          rotateSlot: item.index - 1,\n          slotCount: _bentoItems.length - 1,\n          sourceListingIds: sourceListingIds,\n          handoffCategoryId: isListingPreviewQuickFilter ? item.id : null,\n          onTap: () {"""
assert old in text
text = text.replace(old, new, 1)

old = """    this.enableVideo = true,\n    this.sourceListingIds = const <String, String>{},\n    this.handoffCategoryId,"""
new = """    this.enableVideo = true,\n    this.rotateSlot = 0,\n    this.slotCount = 1,\n    this.sourceListingIds = const <String, String>{},\n    this.handoffCategoryId,"""
assert old in text
text = text.replace(old, new, 1)

old = """  final bool enableVideo;\n  final Map<String, String> sourceListingIds;"""
new = """  final bool enableVideo;\n  final int rotateSlot;\n  final int slotCount;\n  final Map<String, String> sourceListingIds;"""
assert old in text
text = text.replace(old, new, 1)

old = """class _BentoCardState extends State<_BentoCard> {\n  bool _pressed = false;\n  int _mediaIndex = 0;\n  Timer? _previewTimer;\n  final math.Random _previewRandom = math.Random();\n\n  @override\n  void initState() {\n    super.initState();\n    if (widget.media.length > 1) {\n      _mediaIndex = _previewRandom.nextInt(widget.media.length);\n    }\n    _scheduleNextPreview();\n  }\n\n  @override\n  void didUpdateWidget(covariant _BentoCard oldWidget) {\n    super.didUpdateWidget(oldWidget);\n    if (widget.media.isEmpty) {\n      _mediaIndex = 0;\n    } else if (_mediaIndex >= widget.media.length) {\n      _mediaIndex %= widget.media.length;\n    }\n  }\n\n  @override\n  void dispose() {\n    _previewTimer?.cancel();\n    super.dispose();\n  }\n\n  void _scheduleNextPreview() {\n    _previewTimer?.cancel();\n    // A fresh 5-7 second delay per card keeps the grid feeling alive without\n    // making every tile flip at the same instant.\n    final delay = Duration(milliseconds: 5000 + _previewRandom.nextInt(2001));\n    _previewTimer = Timer(delay, () {\n      if (!mounted) return;\n      final mediaCount = widget.media.length;\n      if (mediaCount > 1 && TickerMode.of(context)) {\n        setState(() => _mediaIndex = (_mediaIndex + 1) % mediaCount);\n      }\n      _scheduleNextPreview();\n    });\n  }"""
new = """class _BentoCardState extends State<_BentoCard> {\n  bool _pressed = false;"""
assert old in text
text = text.replace(old, new, 1)

old = """  @override\n  Widget build(BuildContext context) {\n    final previewSources = widget.media.isEmpty\n        ? const <String>[]\n        : <String>[widget.media[_mediaIndex % widget.media.length]];\n\n    return AnimatedScale("""
new = """  @override\n  Widget build(BuildContext context) {\n    return AnimatedScale("""
assert old in text
text = text.replace(old, new, 1)

old = """                child: QuickFilterMedia(\n                  sources: previewSources,\n                  enableVideo: false,\n                  showMute: false,\n                ),"""
new = """                child: QuickFilterMedia(\n                  sources: widget.media,\n                  rotateSlot: widget.rotateSlot,\n                  slotCount: widget.slotCount,\n                  enableVideo: widget.enableVideo,\n                  showMute: widget.enableVideo,\n                  sourceListingIds: widget.sourceListingIds,\n                  handoffCategoryId: widget.handoffCategoryId,\n                ),"""
assert old in text
text = text.replace(old, new, 1)

bento.write_text(text)
print('Sequential dashboard media patch applied.')
