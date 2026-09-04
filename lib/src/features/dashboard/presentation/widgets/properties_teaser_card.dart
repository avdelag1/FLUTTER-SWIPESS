import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart';
import 'package:video_player/video_player.dart';

/// Properties dashboard media using the same simple controller lifecycle as
/// [EventsTeaserCard]: one current controller, one prepared next controller,
/// no preview seek tricks and no generic quick-filter decoder/budget pipeline.
///
/// Listing videos remain manual-play. Left/right taps change the visible
/// listing, center opens that exact listing, and a completed video advances one
/// listing then leaves the next item paused.
class PropertiesTeaserCard extends StatefulWidget {
  const PropertiesTeaserCard({
    super.key,
    required this.listings,
    required this.onOpen,
  });

  final List<Listing> listings;
  final ValueChanged<String?> onOpen;

  @override
  State<PropertiesTeaserCard> createState() => _PropertiesTeaserCardState();
}

class _PropertiesTeaserCardState extends State<PropertiesTeaserCard>
    with WidgetsBindingObserver {
  VideoPlayerController? _current;
  VideoPlayerController? _preloaded;
  int? _preloadedIndex;
  String? _boundListingId;
  String? _boundVideoUrl;

  int _index = 0;
  bool _loading = false;
  bool _switching = false;
  bool _completionQueued = false;
  bool _routeActive = true;
  bool _appActive = true;
  bool _manualPlaying = false;
  bool _soundOn = false;
  bool _mediaUnlocked = false;

  List<Listing> get _items {
    final seen = <String>{};
    return widget.listings
        .where((listing) {
          final video = _videoUrl(listing);
          final image = _imageUrl(listing);
          if (video == null && image == null) return false;
          final key = listing.id.trim().isNotEmpty
              ? listing.id.trim()
              : (video ?? image ?? '');
          return seen.add(key);
        })
        .toList(growable: false);
  }

  String? _videoUrl(Listing listing) {
    // The listings.video_url column is promoted to the optimized fast-start
    // MP4 when processing succeeds. Use that direct file here, matching the
    // simple Events network-player path instead of adaptive/generic selection.
    final value = listing.videoUrl?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _imageUrl(Listing listing) {
    final value = listing.primaryImage?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get _canRun => _routeActive && _appActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (_routeActive == active) return;
    _routeActive = active;
    if (!active) {
      unawaited(_pauseCurrent(resumeEvents: true));
      unawaited(_preloaded?.pause() ?? Future<void>.value());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appActive = true;
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appActive = false;
        unawaited(_pauseCurrent(resumeEvents: true));
        unawaited(_preloaded?.pause() ?? Future<void>.value());
        break;
    }
  }

  @override
  void didUpdateWidget(covariant PropertiesTeaserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final items = _items;
    if (items.isEmpty) {
      unawaited(_resetPlayers());
      return;
    }

    var nextIndex = _index.clamp(0, items.length - 1);
    if (_boundListingId != null) {
      final matching = items.indexWhere((item) => item.id == _boundListingId);
      if (matching >= 0) nextIndex = matching;
    }

    final nextListing = items[nextIndex];
    final nextVideo = _videoUrl(nextListing);
    final sourceChanged =
        nextListing.id != _boundListingId || nextVideo != _boundVideoUrl;
    _index = nextIndex;

    if (sourceChanged) {
      unawaited(_loadIndex(nextIndex));
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachCurrentListener(_current);
    resumeDashboardEventsPreviewAfterListing();
    _current?.dispose();
    _preloaded?.dispose();
    super.dispose();
  }

  Future<VideoPlayerController?> _prepare(Listing listing) async {
    final raw = _videoUrl(listing);
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }

  void _attachCurrentListener(VideoPlayerController controller) {
    controller.removeListener(_onCurrentTick);
    controller.addListener(_onCurrentTick);
  }

  void _detachCurrentListener(VideoPlayerController? controller) {
    controller?.removeListener(_onCurrentTick);
  }

  void _onCurrentTick() {
    final controller = _current;
    if (!mounted ||
        controller == null ||
        !_manualPlaying ||
        _completionQueued ||
        _switching ||
        !_canRun) {
      return;
    }

    final value = controller.value;
    if (!value.isInitialized || value.duration <= Duration.zero) return;
    final remainingMs =
        value.duration.inMilliseconds - value.position.inMilliseconds;
    if (value.position > Duration.zero && remainingMs <= 180) {
      _completionQueued = true;
      unawaited(_finishCurrentVideo());
    }
  }

  Future<void> _finishCurrentVideo() async {
    final items = _items;
    if (items.length <= 1) {
      final controller = _current;
      _manualPlaying = false;
      resumeDashboardEventsPreviewAfterListing();
      if (controller != null && controller.value.isInitialized) {
        try {
          await controller.pause();
          await controller.setVolume(0);
          await controller.seekTo(Duration.zero);
        } catch (_) {}
      }
      _completionQueued = false;
      if (mounted) setState(() {});
      return;
    }

    await _advance(1);
  }

  Future<void> _ensureLoaded() async {
    if (!mounted || _loading || _switching) return;
    final items = _items;
    if (items.isEmpty) return;
    if (_index >= items.length) _index = 0;

    final listing = items[_index];
    final wantedVideo = _videoUrl(listing);
    if (_boundListingId == listing.id &&
        _boundVideoUrl == wantedVideo &&
        (wantedVideo == null ||
            (_current != null && _current!.value.isInitialized))) {
      return;
    }

    await _loadIndex(_index);
  }

  Future<void> _loadIndex(int target) async {
    if (!mounted || _loading) return;
    final items = _items;
    if (items.isEmpty) return;
    var safeTarget = target % items.length;
    if (safeTarget < 0) safeTarget += items.length;

    _loading = true;
    final listing = items[safeTarget];
    final video = _videoUrl(listing);
    final previous = _current;
    _detachCurrentListener(previous);
    _current = null;
    _boundListingId = listing.id;
    _boundVideoUrl = video;
    _manualPlaying = false;
    _completionQueued = false;
    resumeDashboardEventsPreviewAfterListing();

    if (mounted) {
      setState(() => _index = safeTarget);
    } else {
      _index = safeTarget;
    }

    try {
      VideoPlayerController? next;
      if (video != null &&
          _preloaded != null &&
          _preloadedIndex == safeTarget &&
          _preloaded!.value.isInitialized) {
        next = _preloaded;
        _preloaded = null;
        _preloadedIndex = null;
      } else if (video != null) {
        next = await _prepare(listing);
      }

      if (!mounted || _boundListingId != listing.id) {
        await next?.dispose();
        return;
      }

      _current = next;
      if (next != null) _attachCurrentListener(next);
      if (mounted) setState(() {});
      unawaited(_preloadNext());
    } finally {
      _loading = false;
      if (previous != null && !identical(previous, _current)) {
        Future<void>.delayed(const Duration(milliseconds: 520), () async {
          try {
            await previous.setVolume(0);
            await previous.pause();
            await previous.dispose();
          } catch (_) {}
        });
      }
    }
  }

  Future<void> _preloadNext() async {
    final items = _items;
    if (!mounted || items.length < 2) return;
    final target = (_index + 1) % items.length;
    final listing = items[target];
    if (_videoUrl(listing) == null) {
      final old = _preloaded;
      _preloaded = null;
      _preloadedIndex = null;
      await old?.dispose();
      return;
    }

    if (_preloaded != null &&
        _preloadedIndex == target &&
        _preloaded!.value.isInitialized) {
      return;
    }

    final prepared = await _prepare(listing);
    if (!mounted || target != ((_index + 1) % _items.length)) {
      await prepared?.dispose();
      return;
    }

    final old = _preloaded;
    _preloaded = prepared;
    _preloadedIndex = prepared == null ? null : target;
    await old?.dispose();
  }

  Future<void> _advance(int delta) async {
    final items = _items;
    if (items.length <= 1 || _switching) return;
    _switching = true;
    try {
      await _pauseCurrent(resumeEvents: true);
      var target = (_index + delta) % items.length;
      if (target < 0) target += items.length;
      await _loadIndex(target);
    } finally {
      _switching = false;
    }
  }

  Future<void> _pauseCurrent({required bool resumeEvents}) async {
    _manualPlaying = false;
    final controller = _current;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setVolume(0);
        if (controller.value.isPlaying) await controller.pause();
      } catch (_) {}
    }
    if (resumeEvents) resumeDashboardEventsPreviewAfterListing();
    if (mounted) setState(() {});
  }

  Future<void> _playWithWebFallback(VideoPlayerController controller) async {
    try {
      await controller.play();
    } catch (_) {
      if (!kIsWeb) return;
      try {
        await controller.setVolume(0);
        await controller.play();
      } catch (_) {}
    }
  }

  Future<void> _togglePlayback() async {
    final items = _items;
    if (items.isEmpty) return;
    final listing = items[_index % items.length];
    if (_videoUrl(listing) == null) return;

    var controller = _current;
    if (controller == null ||
        !controller.value.isInitialized ||
        _boundListingId != listing.id) {
      await _loadIndex(_index);
      controller = _current;
    }
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }

    if (_manualPlaying || controller.value.isPlaying) {
      await _pauseCurrent(resumeEvents: true);
      return;
    }

    pauseDashboardEventsPreviewForListing();
    _manualPlaying = true;
    _completionQueued = false;
    final wantSound = _soundOn && (_mediaUnlocked || !kIsWeb);
    try {
      await controller.setVolume(0);
      await _playWithWebFallback(controller);
      if (wantSound && controller.value.isPlaying) {
        await controller.setVolume(1);
      }
    } catch (_) {
      _manualPlaying = false;
      resumeDashboardEventsPreviewAfterListing();
    }
    if (mounted) setState(() {});
  }

  void _toggleSound() {
    AppHaptics.selection();
    unlockDeckMedia();
    final next = !_soundOn;
    if (next) _mediaUnlocked = true;
    setState(() => _soundOn = next);

    final controller = _current;
    if (controller != null &&
        controller.value.isInitialized &&
        _manualPlaying) {
      unawaited(controller.setVolume(next ? 1 : 0));
    }
  }

  void _openCurrent() {
    final items = _items;
    if (items.isEmpty) {
      widget.onOpen(null);
      return;
    }

    final listing = items[_index % items.length];
    final controller = _current;
    final video = _videoUrl(listing);
    AppHaptics.light();

    if (video != null &&
        controller != null &&
        controller.value.isInitialized &&
        _boundListingId == listing.id) {
      unlockDeckMedia();
      _detachCurrentListener(controller);
      SwipeDeckMediaHandoff.set(
        SwipeDeckMediaHandoffData(
          videoUrl: video,
          position: controller.value.position,
          controller: controller,
          wantSound: _soundOn && (_mediaUnlocked || !kIsWeb),
          listingId: listing.id,
          categoryId: 'property',
        ),
      );
      _current = null;
      _boundListingId = null;
      _boundVideoUrl = null;
      _manualPlaying = false;
      final preloaded = _preloaded;
      _preloaded = null;
      _preloadedIndex = null;
      if (preloaded != null) unawaited(preloaded.dispose());
    }

    widget.onOpen(listing.id);
  }

  Future<void> _resetPlayers() async {
    _detachCurrentListener(_current);
    final current = _current;
    final preloaded = _preloaded;
    _current = null;
    _preloaded = null;
    _preloadedIndex = null;
    _boundListingId = null;
    _boundVideoUrl = null;
    _manualPlaying = false;
    _completionQueued = false;
    resumeDashboardEventsPreviewAfterListing();
    try {
      await current?.dispose();
    } catch (_) {}
    try {
      await preloaded?.dispose();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Widget _poster(Listing listing) {
    final image = _imageUrl(listing);
    if (image == null) return const ColoredBox(color: Color(0xFF15171C));
    return Image.network(
      image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF15171C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) {
      return const ColoredBox(color: Color(0xFF15171C));
    }

    final safeIndex = _index.clamp(0, items.length - 1);
    final listing = items[safeIndex];
    final video = _videoUrl(listing);
    final controller = _current;
    final ready =
        video != null &&
        controller != null &&
        controller.value.isInitialized &&
        _boundListingId == listing.id;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          reverseDuration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(.028, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.02, end: 1).animate(curved),
                  child: child,
                ),
              ),
            );
          },
          child: ready
              ? _PropertiesCoverVideo(
                  key: ValueKey('video:${listing.id}:$video'),
                  controller: controller,
                )
              : KeyedSubtree(
                  key: ValueKey('poster:${listing.id}:${_imageUrl(listing)}'),
                  child: _poster(listing),
                ),
        ),

        // Quick-filter interaction contract: left = previous, center = open the
        // exact listing shown, right = next. No horizontal swipe gesture.
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                flex: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    AppHaptics.selection();
                    if (items.length > 1) {
                      unawaited(_advance(-1));
                    } else {
                      _openCurrent();
                    }
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                flex: 40,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openCurrent,
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                flex: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    AppHaptics.selection();
                    if (items.length > 1) {
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

        if (items.length > 1)
          Positioned(
            top: 10,
            left: 10,
            right: 52,
            child: IgnorePointer(
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
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

        if (video != null)
          Positioned(
            bottom: 76,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(145),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(42)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'VIDEO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (video != null)
          Positioned(
            right: 6,
            bottom: 7,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _toggleSound,
                  behavior: HitTestBehavior.opaque,
                  child: _controlButton(
                    _soundOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => unawaited(_togglePlayback()),
                  behavior: HitTestBehavior.opaque,
                  child: _controlButton(
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

  Widget _controlButton(IconData icon) {
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

/// Same cover renderer used by EventsTeaserCard.
class _PropertiesCoverVideo extends StatelessWidget {
  const _PropertiesCoverVideo({super.key, required this.controller});

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
