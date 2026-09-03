import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/event_preview_handoff.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

/// Dashboard Events teaser.
///
/// Each unique event video plays exactly once, then advances immediately to the
/// next unique event. Short clips are never looped to fill an artificial slot.
/// The list repeats only after every available video has been shown.
class EventsTeaserCard extends ConsumerStatefulWidget {
  const EventsTeaserCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  ConsumerState<EventsTeaserCard> createState() => _EventsTeaserCardState();
}

class _EventsTeaserCardState extends ConsumerState<EventsTeaserCard>
    with WidgetsBindingObserver {
  VideoPlayerController? _current;
  VideoPlayerController? _preloaded;
  int? _preloadedIndex;
  int _index = 0;
  bool _loading = false;
  bool _switching = false;
  bool _completionQueued = false;
  bool _routeActive = true;
  bool _appActive = true;
  bool _videoPreviewEnabled = true;
  double _dragDx = 0;

  bool get _canPlay => _routeActive && _appActive && _videoPreviewEnabled;

  List<Event> _uniqueVideos(Iterable<Event> source) {
    final seen = <String>{};
    final out = <Event>[];
    for (final event in source) {
      final raw = event.videoUrl?.trim();
      if (raw == null || raw.isEmpty) continue;
      final key = raw.toLowerCase();
      if (seen.add(key)) out.add(event);
    }
    return out;
  }

  List<Event> get _videos => _uniqueVideos(
        ref.read(dashboardVideoEventsProvider).value ?? const <Event>[],
      );

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
    if (_canPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumePlayback());
    } else {
      _current?.pause();
      _preloaded?.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appActive = true;
        if (mounted && _videoPreviewEnabled) unawaited(_resumePlayback());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appActive = false;
        _current?.pause();
        _preloaded?.pause();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _current?.dispose();
    _preloaded?.dispose();
    super.dispose();
  }

  Future<VideoPlayerController?> _prepare(Event event) async {
    final raw = event.videoUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      // Important: never loop one short event several times before advancing.
      await controller.setLooping(false);
      await controller.setVolume(0);
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }

  void _watchForCompletion(VideoPlayerController controller) {
    controller.addListener(() {
      if (!mounted ||
          !identical(controller, _current) ||
          _completionQueued ||
          _switching ||
          !_canPlay) {
        return;
      }
      final value = controller.value;
      if (!value.isInitialized || value.duration <= Duration.zero) return;
      final remainingMs =
          value.duration.inMilliseconds - value.position.inMilliseconds;
      if (value.position > Duration.zero && remainingMs <= 180) {
        _completionQueued = true;
        unawaited(_advance(1));
      }
    });
  }

  Future<void> _ensureLoaded() async {
    if (!mounted || _loading || _switching) return;
    final videos = _videos;
    if (videos.isEmpty) return;

    if (_current != null && _index < videos.length) {
      if (_videoPreviewEnabled) await _resumePlayback();
      return;
    }

    _loading = true;
    try {
      // Start at a changing position so every fresh session does not always
      // begin with event zero, while preserving sequential playback afterward.
      final seed = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 30000;
      final start = videos.length <= 1 ? 0 : seed % videos.length;

      for (var attempt = 0; attempt < videos.length; attempt++) {
        final candidate = (start + attempt) % videos.length;
        final controller = await _prepare(videos[candidate]);
        if (!mounted) {
          await controller?.dispose();
          return;
        }
        if (controller == null) continue;

        _index = candidate;
        _current = controller;
        _completionQueued = false;
        _watchForCompletion(controller);
        await _applySound();
        if (_canPlay) await _playWithWebFallback(controller);
        if (mounted) setState(() {});
        if (_videoPreviewEnabled) unawaited(_preloadNext(videos));
        return;
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _resumePlayback() async {
    if (!_videoPreviewEnabled) return;
    final current = _current;
    if (current == null || !current.value.isInitialized) {
      await _ensureLoaded();
      return;
    }

    final duration = current.value.duration;
    final position = current.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 180)) {
      _completionQueued = true;
      await _advance(1);
      return;
    }

    await _applySound();
    if (_canPlay) await _playWithWebFallback(current);
  }

  Future<void> _preloadNext(List<Event> videos) async {
    if (!mounted || !_videoPreviewEnabled || videos.length < 2) return;
    final target = (_index + 1) % videos.length;
    final prepared = await _prepare(videos[target]);
    if (!mounted || !_videoPreviewEnabled) {
      await prepared?.dispose();
      return;
    }

    final old = _preloaded;
    _preloaded = prepared;
    _preloadedIndex = prepared == null ? null : target;
    await old?.dispose();
  }

  Future<void> _advance(int delta) async {
    final videos = _videos;
    if (videos.isEmpty || _switching) return;

    if (videos.length == 1) {
      final current = _current;
      if (current != null && current.value.isInitialized) {
        await current.seekTo(Duration.zero);
        _completionQueued = false;
        if (_canPlay) await _playWithWebFallback(current);
      }
      return;
    }

    _switching = true;
    try {
      for (var attempt = 1; attempt <= videos.length; attempt++) {
        var target = (_index + (delta * attempt)) % videos.length;
        if (target < 0) target += videos.length;

        VideoPlayerController? next;
        if (delta == 1 &&
            attempt == 1 &&
            _preloaded != null &&
            _preloadedIndex == target &&
            _preloaded!.value.isInitialized) {
          next = _preloaded;
          _preloaded = null;
          _preloadedIndex = null;
        } else {
          next = await _prepare(videos[target]);
        }
        if (!mounted) {
          await next?.dispose();
          return;
        }
        if (next == null) continue;

        final previous = _current;
        _current = next;
        _index = target;
        _completionQueued = false;
        _watchForCompletion(next);
        await _applySound();
        if (_canPlay) await _playWithWebFallback(next);
        if (mounted) setState(() {});

        if (previous != null) {
          Future<void>.delayed(const Duration(milliseconds: 520), () async {
            try {
              await previous.setVolume(0);
              await previous.pause();
              await previous.dispose();
            } catch (_) {}
          });
        }

        if (_videoPreviewEnabled) unawaited(_preloadNext(videos));
        return;
      }
    } finally {
      _switching = false;
    }
  }


  Future<void> _playWithWebFallback(VideoPlayerController player) async {
    try {
      await player.play();
    } catch (e) {
      if (kIsWeb) {
        try {
          await player.setVolume(0);
          await player.play();
        } catch (_) {}
      }
    }
  }

  Future<void> _applySound() async {
    final current = _current;
    if (current == null) return;
    final soundOn = ref.read(deckSoundOnProvider);
    final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
    final wantSound = soundOn && (unlocked || !kIsWeb);
    try {
      await current.setVolume(wantSound && _canPlay ? 1 : 0);
    } catch (_) {}
  }

  void _toggleSound() {
    AppHaptics.selection();
    unlockDeckMedia();
    final next = !ref.read(deckSoundOnProvider);
    ref.read(deckSoundOnProvider.notifier).setSoundOn(next);
    unawaited(_applySound());
  }

  void _toggleVideoPreview() {
    AppHaptics.selection();
    final next = !_videoPreviewEnabled;
    setState(() => _videoPreviewEnabled = next);

    if (!next) {
      // Keep the initialized current controller as a frozen poster frame, but
      // stop playback and throw away the hidden preloaded decoder immediately.
      unawaited(_current?.pause() ?? Future<void>.value());
      unawaited(_applySound());
      final preloaded = _preloaded;
      _preloaded = null;
      _preloadedIndex = null;
      if (preloaded != null) unawaited(preloaded.dispose());
      return;
    }

    unawaited(_resumePlayback());
    final videos = _videos;
    if (videos.length > 1) unawaited(_preloadNext(videos));
  }

  void _openEvents(List<Event> videos) {
    if (videos.isEmpty || _index >= videos.length) {
      AppHaptics.medium();
      widget.onTap?.call();
      return;
    }

    final event = videos[_index];
    final player = _current;
    final transferable =
        player != null && player.value.isInitialized ? player : null;
    final soundOn = ref.read(deckSoundOnProvider);

    // Keep web audio unlocked in the same tap gesture that opens Events.
    unlockDeckMedia();
    if (soundOn) {
      ref.read(deckSoundOnProvider.notifier).preserveAudibleHandoff();
    }

    EventPreviewHandoff.set(
      eventId: event.id,
      position: transferable?.value.position ?? Duration.zero,
      controller: transferable,
      wantSound: soundOn,
    );

    // Hide the dashboard header/dock before navigation so the very first Events
    // frame is already edge-to-edge instead of animating through an inset card.
    ref.read(chromeVisibilityProvider.notifier).hide();
    AppHaptics.medium();

    // Temporarily release ownership without pausing. The full-screen Events page
    // can adopt the exact initialized controller during the route change, so the
    // movie continues instead of reconnecting/buffering from the network.
    if (transferable != null && identical(_current, transferable)) {
      _current = null;
      _completionQueued = false;
    }

    unawaited(ref.read(eventsListProvider.notifier).refresh());

    widget.onTap?.call();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final location = GoRouterState.of(context).matchedLocation;
      final openedEvents = location == AppPaths.exploreEvents;

      if (openedEvents) {
        final preloaded = _preloaded;
        _preloaded = null;
        _preloadedIndex = null;
        if (preloaded != null) unawaited(preloaded.dispose());
        return;
      }

      // Access may have been blocked by Premium/market gating. In that case the
      // user never left the dashboard: cancel the handoff and restore the same
      // player immediately so the preview does not flash or restart.
      EventPreviewHandoff.clear();
      ref.read(chromeVisibilityProvider.notifier).show();
      if (transferable != null && _current == null) {
        _current = transferable;
        unawaited(_applySound());
        if (_canPlay) unawaited(_playWithWebFallback(transferable));
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teaserAsync = ref.watch(dashboardVideoEventsProvider);
    final videos = _uniqueVideos(teaserAsync.value ?? const <Event>[]);
    final soundOn = ref.watch(deckSoundOnProvider);

    ref.listen<AsyncValue<List<Event>>>(dashboardVideoEventsProvider, (_, next) {
      final loaded = _uniqueVideos(next.value ?? const <Event>[]);
      if (loaded.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
      }
    });
    ref.listen<bool>(deckSoundOnProvider, (_, __) => _applySound());

    final safeIndex = videos.isEmpty ? 0 : _index % videos.length;
    final event = videos.isEmpty ? null : videos[safeIndex];
    final controller = _current;
    final ready = controller != null && controller.value.isInitialized;

    return ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF080A0F)),
            if (ready)
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
                child: _CoverVideo(
                  key: ValueKey(event?.videoUrl ?? safeIndex),
                  controller: controller,
                ),
              )
            else
              Center(
                child: teaserAsync.hasError
                    ? IconButton(
                        tooltip: 'Retry event videos',
                        onPressed: () {
                          ref.invalidate(dashboardVideoEventsProvider);
                        },
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      )
                    : SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Colors.white,
                        ),
                      ),
              ),
            // Tap + horizontal swipe live in a layer that excludes the media
            // controls so sound/play stay instant and swiping still advances.
            Positioned(
              top: 0,
              left: 0,
              right: 48,
              bottom: 72,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openEvents(videos),
                onHorizontalDragStart: (_) => _dragDx = 0,
                onHorizontalDragUpdate: (details) =>
                    _dragDx += details.delta.dx,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  final gesture = velocity.abs() >= 100 ? velocity : _dragDx;
                  if (videos.length > 1 &&
                      (gesture.abs() >= 8 || _dragDx.abs() >= 8)) {
                    AppHaptics.selection();
                    unawaited(_advance(gesture < 0 ? 1 : -1));
                  }
                  _dragDx = 0;
                },
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleSound,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(132),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(48)),
                      ),
                      child: Icon(
                        soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x18000000),
                      Color(0x00000000),
                      Color(0xB8000000),
                    ],
                    stops: [0, .48, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 13,
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(125),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(42)),
                  ),
                  child: Text(
                    'EVENTS  •  LIVE',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 15,
              right: 15,
              bottom: 15,
              child: IgnorePointer(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            event?.title.trim().isNotEmpty == true
                                ? event!.title.toUpperCase()
                                : 'WHAT\'S HAPPENING',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.35,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            videos.length > 1
                                ? 'Live event stream · swipe left or right'
                                : 'Tap to explore events',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 42),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _CoverVideo extends StatelessWidget {
  const _CoverVideo({super.key, required this.controller});

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
