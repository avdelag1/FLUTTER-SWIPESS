import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart';
import 'package:video_player/video_player.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Dedicated Properties teaser player using the same deliberately simple
/// controller lifecycle as Events: prepare one current controller, preload one
/// next controller, and never route listing playback through QuickFilterMedia's
/// shared decoder budget/warm-frame machinery.
class PropertyTeaserCard extends StatefulWidget {
  const PropertyTeaserCard({
    super.key,
    required this.media,
    required this.sourceListingIdsByIndex,
    required this.videoPosterUrlsByIndex,
    required this.sourceListingIds,
    required this.sourceImageListingIds,
    required this.videoPosterUrls,
    required this.onOpen,
  });

  final List<String> media;
  final List<String?> sourceListingIdsByIndex;
  final List<String?> videoPosterUrlsByIndex;
  final Map<String, String> sourceListingIds;
  final Map<String, String> sourceImageListingIds;
  final Map<String, String> videoPosterUrls;
  final ValueChanged<String?> onOpen;

  @override
  State<PropertyTeaserCard> createState() => _PropertyTeaserCardState();
}

class _PropertyTeaserCardState extends State<PropertyTeaserCard>
    with WidgetsBindingObserver {
  VideoPlayerController? _current;
  String? _currentUrl;
  VideoPlayerController? _preloaded;
  int? _preloadedIndex;
  Timer? _rotateTimer;
  int _index = 0;
  bool _loading = false;
  bool _manualPlaying = false;
  bool _soundOn = false;
  bool _mediaUnlocked = false;
  bool _routeActive = true;
  bool _appActive = true;
  bool _completionQueued = false;
  late final VoidCallback _dashboardPauseHook;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardPauseHook = () {
      unawaited(_pausePlayback(resumeEvents: false));
    };
    registerDedicatedListingPlaybackPause(_dashboardPauseHook);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_ensureCurrentPrepared());
      _scheduleRotation();
    });
  }

  @override
  void didUpdateWidget(covariant PropertyTeaserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(oldWidget.media, widget.media) &&
        listEquals(
          oldWidget.sourceListingIdsByIndex,
          widget.sourceListingIdsByIndex,
        ) &&
        listEquals(
          oldWidget.videoPosterUrlsByIndex,
          widget.videoPosterUrlsByIndex,
        )) {
      return;
    }
    if (widget.media.isEmpty) {
      _index = 0;
      unawaited(_disposePlayers());
      return;
    }
    if (_index >= widget.media.length) _index %= widget.media.length;
    final url = widget.media[_index];
    if (_currentUrl != url) unawaited(_replaceForIndex(_index));
    _scheduleRotation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (_routeActive == active) return;
    _routeActive = active;
    if (!_routeActive) {
      unawaited(_pausePlayback(resumeEvents: true));
    } else {
      unawaited(_ensureCurrentPrepared());
      _scheduleRotation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appActive = true;
        unawaited(_ensureCurrentPrepared());
        _scheduleRotation();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appActive = false;
        unawaited(_pausePlayback(resumeEvents: true));
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unregisterDedicatedListingPlaybackPause(_dashboardPauseHook);
    _rotateTimer?.cancel();
    _current?.removeListener(_onPlayerTick);
    unawaited(_current?.dispose() ?? Future<void>.value());
    unawaited(_preloaded?.dispose() ?? Future<void>.value());
    resumeDashboardEventsPreviewAfterListing();
    super.dispose();
  }

  Future<void> _disposePlayers() async {
    _rotateTimer?.cancel();
    _current?.removeListener(_onPlayerTick);
    final current = _current;
    final preloaded = _preloaded;
    _current = null;
    _currentUrl = null;
    _preloaded = null;
    _preloadedIndex = null;
    _manualPlaying = false;
    if (current != null) await current.dispose();
    if (preloaded != null) await preloaded.dispose();
    resumeDashboardEventsPreviewAfterListing();
  }

  bool _isVideo(String url) => isQuickFilterVideoUrl(url);

  String? _listingIdForIndex(int index, String url) {
    if (index >= 0 && index < widget.sourceListingIdsByIndex.length) {
      final direct = widget.sourceListingIdsByIndex[index]?.trim();
      if (direct != null && direct.isNotEmpty) return direct;
    }
    final normalized = url.trim();
    return widget.sourceListingIds[normalized] ??
        widget.sourceImageListingIds[normalized];
  }

  String? _posterForIndex(int index, String url) {
    if (index >= 0 && index < widget.videoPosterUrlsByIndex.length) {
      final direct = widget.videoPosterUrlsByIndex[index]?.trim();
      if (direct != null && direct.isNotEmpty) return direct;
    }
    final poster = widget.videoPosterUrls[url.trim()]?.trim();
    return poster == null || poster.isEmpty ? null : poster;
  }

  Future<VideoPlayerController?> _prepare(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setPlaybackSpeed(1.0);
      await controller.setVolume(0);
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }

  Future<void> _ensureCurrentPrepared() async {
    if (!mounted ||
        _loading ||
        !_routeActive ||
        !_appActive ||
        widget.media.isEmpty) {
      return;
    }
    final safeIndex = _index % widget.media.length;
    final url = widget.media[safeIndex].trim();
    if (!_isVideo(url)) return;
    if (_current != null &&
        _currentUrl == url &&
        _current!.value.isInitialized) {
      return;
    }

    _loading = true;
    try {
      VideoPlayerController? prepared;
      if (_preloaded != null &&
          _preloadedIndex == safeIndex &&
          _preloaded!.value.isInitialized) {
        prepared = _preloaded;
        _preloaded = null;
        _preloadedIndex = null;
      } else {
        prepared = await _prepare(url);
      }
      if (!mounted) {
        await prepared?.dispose();
        return;
      }
      if (prepared == null) return;

      final old = _current;
      old?.removeListener(_onPlayerTick);
      _current = prepared;
      _currentUrl = url;
      _completionQueued = false;
      prepared.addListener(_onPlayerTick);
      if (mounted) setState(() {});
      if (old != null) unawaited(old.dispose());
      unawaited(_preloadNext());
    } finally {
      _loading = false;
    }
  }

  Future<void> _preloadNext() async {
    if (!mounted || widget.media.length < 2 || !_routeActive || !_appActive)
      return;
    final target = (_index + 1) % widget.media.length;
    final url = widget.media[target].trim();
    if (!_isVideo(url)) {
      final old = _preloaded;
      _preloaded = null;
      _preloadedIndex = null;
      if (old != null) unawaited(old.dispose());
      return;
    }
    if (_current != null &&
        _currentUrl == url &&
        _current!.value.isInitialized) {
      final old = _preloaded;
      _preloaded = null;
      _preloadedIndex = null;
      if (old != null) unawaited(old.dispose());
      return;
    }
    if (_preloaded != null && _preloadedIndex == target) return;
    final prepared = await _prepare(url);
    if (!mounted) {
      await prepared?.dispose();
      return;
    }
    final old = _preloaded;
    _preloaded = prepared;
    _preloadedIndex = prepared == null ? null : target;
    if (old != null) unawaited(old.dispose());
  }

  Future<void> _replaceForIndex(int target) async {
    if (!mounted || widget.media.isEmpty) return;
    var nextIndex = target % widget.media.length;
    if (nextIndex < 0) nextIndex += widget.media.length;

    final nextUrl = widget.media[nextIndex].trim();
    final previous = _current;
    final previousUrl = _currentUrl;
    final keepPlaying = _manualPlaying;
    _rotateTimer?.cancel();

    // Separate listings may intentionally share one media file. Change
    // listing identity/index without reconnecting to that same URL.
    if (previous != null &&
        previous.value.isInitialized &&
        previousUrl == nextUrl) {
      _index = nextIndex;
      _completionQueued = false;
      try {
        await previous.seekTo(Duration.zero);
        if (keepPlaying) {
          await previous.setVolume(0);
          await _playWithWebFallback(previous);
          if (_soundOn && (_mediaUnlocked || !kIsWeb)) {
            await previous.setVolume(1);
          }
        }
      } catch (_) {}
      if (mounted) setState(() {});
      unawaited(_preloadNext());
      _scheduleRotation();
      return;
    }

    // Match Events: prepare incoming video before releasing outgoing.
    VideoPlayerController? prepared;
    if (_isVideo(nextUrl)) {
      if (_preloaded != null &&
          _preloadedIndex == nextIndex &&
          _preloaded!.value.isInitialized) {
        prepared = _preloaded;
        _preloaded = null;
        _preloadedIndex = null;
      } else {
        prepared = await _prepare(nextUrl);
      }
      if (!mounted) {
        await prepared?.dispose();
        return;
      }
    }

    previous?.removeListener(_onPlayerTick);
    _index = nextIndex;
    _current = prepared;
    _currentUrl = prepared == null ? null : nextUrl;
    _completionQueued = false;

    if (prepared != null) {
      prepared.addListener(_onPlayerTick);
      if (keepPlaying) {
        await prepared.setVolume(0);
        await _playWithWebFallback(prepared);
        if (_soundOn && (_mediaUnlocked || !kIsWeb)) {
          await prepared.setVolume(1);
        }
        _manualPlaying = true;
      } else {
        _manualPlaying = false;
      }
    } else {
      _manualPlaying = false;
      resumeDashboardEventsPreviewAfterListing();
    }

    if (mounted) setState(() {});

    if (previous != null && !identical(previous, prepared)) {
      Future<void>.delayed(const Duration(milliseconds: 520), () async {
        try {
          await previous.setVolume(0);
          await previous.pause();
          await previous.dispose();
        } catch (_) {}
      });
    }
    unawaited(_preloadNext());
    _scheduleRotation();
  }

  Future<void> _advance(int delta) async {
    if (!mounted || widget.media.length <= 1) return;
    var target = (_index + delta) % widget.media.length;
    if (target < 0) target += widget.media.length;
    await _replaceForIndex(target);
  }

  void _scheduleRotation() {
    _rotateTimer?.cancel();
    if (!mounted || widget.media.length <= 1 || _manualPlaying) return;
    _rotateTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _manualPlaying) return;
      unawaited(_advance(1));
    });
  }

  Future<void> _playWithWebFallback(VideoPlayerController player) async {
    try {
      await player.play();
    } catch (_) {
      if (kIsWeb) {
        try {
          await player.setVolume(0);
          await player.play();
        } catch (_) {}
      }
    }
  }

  Future<void> _startPlayback() async {
    if (widget.media.isEmpty) return;
    final url = widget.media[_index % widget.media.length].trim();
    if (!_isVideo(url)) return;

    _rotateTimer?.cancel();
    pauseQuickFilterVideoPlayback();
    pauseDedicatedListingVideoPlayback(except: _dashboardPauseHook);
    pauseDashboardEventsPreviewForListing();
    _manualPlaying = true;
    await _ensureCurrentPrepared();
    final player = _current;
    if (!mounted || player == null || !player.value.isInitialized) {
      _manualPlaying = false;
      resumeDashboardEventsPreviewAfterListing();
      _scheduleRotation();
      return;
    }

    final duration = player.value.duration;
    if (duration > Duration.zero &&
        player.value.position >= duration - const Duration(milliseconds: 180)) {
      await player.seekTo(Duration.zero);
    }
    await player.setVolume(0);
    await _playWithWebFallback(player);
    if (_soundOn && (_mediaUnlocked || !kIsWeb)) await player.setVolume(1);
    if (mounted) setState(() {});
  }

  Future<void> _pausePlayback({required bool resumeEvents}) async {
    _manualPlaying = false;
    final player = _current;
    if (player != null && player.value.isInitialized) {
      try {
        await player.setVolume(0);
        if (player.value.isPlaying) await player.pause();
      } catch (_) {}
    }
    if (resumeEvents) resumeDashboardEventsPreviewAfterListing();
    if (mounted) setState(() {});
    _scheduleRotation();
  }

  void _onPlayerTick() {
    final player = _current;
    if (!mounted || player == null || !_manualPlaying) return;
    final value = player.value;
    if (!value.isInitialized || value.duration <= Duration.zero) return;

    // Events loops its active video. Properties must never drop a playing
    // video back into the photo/6-second slideshow at the end of the clip.
    final remaining = value.duration - value.position;
    if (!_completionQueued &&
        remaining <= const Duration(milliseconds: 180)) {
      _completionQueued = true;
      return;
    }
    if (_completionQueued && remaining > const Duration(milliseconds: 350)) {
      _completionQueued = false;
    }
  }

  void _toggleSound() {
    AppHaptics.selection();
    unlockDeckMedia();
    final next = !_soundOn;
    if (next) _mediaUnlocked = true;
    setState(() => _soundOn = next);
    final player = _current;
    if (player != null && player.value.isInitialized && _manualPlaying) {
      unawaited(player.setVolume(next ? 1 : 0));
    }
  }

  void _togglePlayback() {
    AppHaptics.selection();
    if (_manualPlaying) {
      unawaited(_pausePlayback(resumeEvents: true));
    } else {
      unawaited(_startPlayback());
    }
  }

  void _openCurrent() {
    if (widget.media.isEmpty) {
      widget.onOpen(null);
      return;
    }
    final url = widget.media[_index % widget.media.length].trim();
    final safeIndex = _index % widget.media.length;
    final listingId = _listingIdForIndex(safeIndex, url);
    final player = _current;
    final transferable =
        _isVideo(url) &&
            player != null &&
            player.value.isInitialized &&
            _currentUrl == url
        ? player
        : null;

    if (transferable != null) {
      unlockDeckMedia();
      SwipeDeckMediaHandoff.set(
        SwipeDeckMediaHandoffData(
          videoUrl: url,
          position: transferable.value.position,
          controller: transferable,
          wantSound: _soundOn && (_mediaUnlocked || !kIsWeb),
          listingId: listingId,
          categoryId: 'property',
        ),
      );
      transferable.removeListener(_onPlayerTick);
      _current = null;
      _currentUrl = null;
      _manualPlaying = false;
    }

    widget.onOpen(listingId);

    if (transferable != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route?.isCurrent != true || _current != null) return;
        SwipeDeckMediaHandoff.clear();
        _current = transferable;
        _currentUrl = url;
        transferable.addListener(_onPlayerTick);
        unawaited(transferable.setVolume(0));
        resumeDashboardEventsPreviewAfterListing();
        setState(() {});
        _scheduleRotation();
      });
    }
  }

  Widget _still(String url) {
    if (url.isEmpty) return const ColoredBox(color: Color(0xFF15171C));
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF15171C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return const ColoredBox(color: Color(0xFF15171C));
    }
    final safeIndex = _index % widget.media.length;
    final url = widget.media[safeIndex].trim();
    final video = _isVideo(url);
    final poster = video ? _posterForIndex(safeIndex, url) : null;
    final player = _current;
    final ready =
        video &&
        player != null &&
        player.value.isInitialized &&
        _currentUrl == url;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (video && ready && _manualPlaying)
          _CoverVideo(controller: player)
        else if (video)
          poster != null
              ? _still(poster)
              : const ColoredBox(color: Color(0xFF15171C))
        else
          _still(url),
        Positioned.fill(
          child: PointerInterceptor(
            // A playing web video must never steal the left/right navigation tap.
            // Keep the shield active for photos too so behavior is identical.
            intercepting: kIsWeb,
            child: Row(
              children: [
                Expanded(
                  flex: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selection();
                      if (widget.media.length > 1) {
                        unawaited(_advance(-1));
                      } else {
                        _openCurrent();
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openCurrent,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  flex: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selection();
                      if (widget.media.length > 1) {
                        unawaited(_advance(1));
                      } else {
                        _openCurrent();
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.media.length > 1)
          Positioned(
            top: 10,
            left: 10,
            right: 52,
            child: IgnorePointer(
              child: Row(
                children: [
                  for (var i = 0; i < widget.media.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Container(
                      width: i == safeIndex ? 14 : 6,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i == safeIndex
                            ? Colors.white
                            : Colors.white.withAlpha(110),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (video)
          Positioned(
            right: 6,
            bottom: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _toggleSound,
                  behavior: HitTestBehavior.opaque,
                  child: _control(
                    _soundOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _togglePlayback,
                  behavior: HitTestBehavior.opaque,
                  child: _control(
                    _manualPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _control(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(132),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(48)),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

class _CoverVideo extends StatelessWidget {
  const _CoverVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.expand();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
