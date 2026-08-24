import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/event_preview_handoff.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

/// Dashboard Events behaves like a live channel rather than a playlist that
/// restarts whenever the dashboard widget is rebuilt.
///
/// Every event owns a 30-second wall-clock slot. The slot is derived from UTC
/// time, so backgrounding, locking the phone, navigating elsewhere, killing the
/// app, or reopening it later cannot reset the stream to event zero. On resume
/// we calculate the event and playback offset that should be live *now*.
class EventsTeaserCard extends ConsumerStatefulWidget {
  const EventsTeaserCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  ConsumerState<EventsTeaserCard> createState() => _EventsTeaserCardState();
}

class _EventsTeaserCardState extends ConsumerState<EventsTeaserCard>
    with WidgetsBindingObserver {
  static const _liveSlot = Duration(seconds: 30);

  VideoPlayerController? _current;
  VideoPlayerController? _preloaded;
  int? _preloadedIndex;
  Timer? _timelineTimer;
  int _index = 0;
  int _browseOffset = 0;
  bool _loading = false;
  bool _switching = false;
  bool _routeActive = true;
  bool _appActive = true;
  double _dragDx = 0;

  bool get _canPlay => _routeActive && _appActive;

  List<Event> get _videos =>
      ref.read(dashboardVideoEventsProvider).value ?? const <Event>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncToTimeline());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (_routeActive == active) return;
    _routeActive = active;
    if (_canPlay) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncToTimeline(forceSeek: true),
      );
    } else {
      _timelineTimer?.cancel();
      _current?.pause();
      _preloaded?.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appActive = true;
        if (mounted) unawaited(_syncToTimeline(forceSeek: true));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appActive = false;
        _timelineTimer?.cancel();
        _current?.pause();
        _preloaded?.pause();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timelineTimer?.cancel();
    _current?.dispose();
    _preloaded?.dispose();
    super.dispose();
  }

  int _globalIndex(DateTime now, int count) {
    if (count <= 1) return 0;
    final slot = now.toUtc().millisecondsSinceEpoch ~/ _liveSlot.inMilliseconds;
    return slot % count;
  }

  int _targetIndex(DateTime now, int count) {
    if (count <= 1) return 0;
    var result = (_globalIndex(now, count) + _browseOffset) % count;
    if (result < 0) result += count;
    return result;
  }

  Duration _slotOffset(DateTime now) {
    final elapsed = now.toUtc().millisecondsSinceEpoch % _liveSlot.inMilliseconds;
    return Duration(milliseconds: elapsed);
  }

  Duration _safeVideoOffset(
    VideoPlayerController controller,
    Duration desired,
  ) {
    final duration = controller.value.duration;
    if (duration <= Duration.zero) return Duration.zero;
    final durationMs = duration.inMilliseconds;
    if (durationMs <= 1) return Duration.zero;
    return Duration(milliseconds: desired.inMilliseconds % durationMs);
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
      // A short source may loop inside its 30-second live slot. The stream only
      // advances events on the shared wall-clock boundary.
      await controller.setLooping(true);
      await controller.setVolume(0);
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }

  Future<void> _seekToLiveOffset(
    VideoPlayerController controller,
    Duration offset,
  ) async {
    try {
      await controller.seekTo(_safeVideoOffset(controller, offset));
    } catch (_) {}
  }

  void _scheduleTimelineBoundary() {
    _timelineTimer?.cancel();
    final videos = _videos;
    if (!_canPlay || videos.length < 2) return;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final slotMs = _liveSlot.inMilliseconds;
    var waitMs = slotMs - (nowMs % slotMs);
    if (waitMs < 40) waitMs += slotMs;
    _timelineTimer = Timer(Duration(milliseconds: waitMs + 20), () {
      if (mounted) unawaited(_syncToTimeline(forceSeek: true));
    });
  }

  Future<void> _syncToTimeline({bool forceSeek = false}) async {
    if (!mounted || _loading || _switching) return;
    final videos = _videos;
    if (videos.isEmpty) return;

    final now = DateTime.now();
    final targetIndex = _targetIndex(now, videos.length);
    final offset = _slotOffset(now);

    if (_current == null) {
      await _loadInitial(videos, targetIndex, offset);
      return;
    }

    if (_index != targetIndex) {
      await _switchTo(videos, targetIndex, offset);
      return;
    }

    if (forceSeek) await _seekToLiveOffset(_current!, offset);
    await _applySound();
    if (_canPlay) await _current?.play();
    _scheduleTimelineBoundary();
  }

  Future<void> _loadInitial(
    List<Event> videos,
    int targetIndex,
    Duration offset,
  ) async {
    if (_loading) return;
    _loading = true;
    try {
      for (var attempt = 0; attempt < videos.length; attempt++) {
        final candidateIndex = (targetIndex + attempt) % videos.length;
        final controller = await _prepare(videos[candidateIndex]);
        if (!mounted) {
          await controller?.dispose();
          return;
        }
        if (controller == null) continue;
        _index = candidateIndex;
        _current = controller;
        await _seekToLiveOffset(controller, offset);
        await _applySound();
        if (_canPlay) await controller.play();
        if (mounted) setState(() {});
        unawaited(_preloadNext(videos));
        _scheduleTimelineBoundary();
        return;
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _preloadNext(List<Event> videos) async {
    if (!mounted || videos.length < 2) return;
    final targetIndex = (_index + 1) % videos.length;
    final prepared = await _prepare(videos[targetIndex]);
    if (!mounted) {
      await prepared?.dispose();
      return;
    }
    final old = _preloaded;
    _preloaded = prepared;
    _preloadedIndex = prepared == null ? null : targetIndex;
    await old?.dispose();
  }

  Future<void> _switchTo(
    List<Event> videos,
    int targetIndex,
    Duration offset,
  ) async {
    if (!mounted || _switching || videos.isEmpty) return;
    _switching = true;
    try {
      VideoPlayerController? next;
      if (_preloaded != null &&
          _preloadedIndex == targetIndex &&
          _preloaded!.value.isInitialized) {
        next = _preloaded;
        _preloaded = null;
        _preloadedIndex = null;
      } else {
        next = await _prepare(videos[targetIndex]);
      }
      if (next == null || !mounted) return;

      final previous = _current;
      _current = next;
      _index = targetIndex;
      await _seekToLiveOffset(next, offset);
      await _applySound();
      if (_canPlay) await next.play();
      if (mounted) setState(() {});

      if (previous != null) {
        Future<void>.delayed(const Duration(milliseconds: 680), () async {
          try {
            await previous.setVolume(0);
            await previous.pause();
            await previous.dispose();
          } catch (_) {}
        });
      }
      unawaited(_preloadNext(videos));
      _scheduleTimelineBoundary();
    } finally {
      _switching = false;
    }
  }

  Future<void> _manualAdvance(int delta) async {
    final videos = _videos;
    if (videos.length < 2 || _switching) return;
    _browseOffset = (_browseOffset + delta) % videos.length;
    final now = DateTime.now();
    final target = _targetIndex(now, videos.length);
    await _switchTo(videos, target, Duration.zero);
  }

  Future<void> _applySound() async {
    final current = _current;
    if (current == null) return;
    final soundOn = ref.read(deckSoundOnProvider);
    try {
      await current.setVolume(soundOn && _canPlay ? 1 : 0);
    } catch (_) {}
  }

  void _toggleSound() {
    AppHaptics.selection();
    unlockDeckMedia();
    final next = !ref.read(deckSoundOnProvider);
    ref.read(deckSoundOnProvider.notifier).setSoundOn(next);
    unawaited(_applySound());
  }

  void _openEvents(List<Event> videos) {
    if (videos.isNotEmpty && _index < videos.length) {
      final player = _current;
      EventPreviewHandoff.set(
        eventId: videos[_index].id,
        position: player != null && player.value.isInitialized
            ? player.value.position
            : Duration.zero,
      );
    }
    AppHaptics.medium();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final teaserAsync = ref.watch(dashboardVideoEventsProvider);
    final videos = teaserAsync.value ?? const <Event>[];
    final soundOn = ref.watch(deckSoundOnProvider);

    ref.listen<AsyncValue<List<Event>>>(dashboardVideoEventsProvider, (
      _,
      next,
    ) {
      final loaded = next.value ?? const <Event>[];
      if (loaded.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _syncToTimeline(forceSeek: true),
        );
      }
    });
    ref.listen<bool>(deckSoundOnProvider, (_, __) => _applySound());

    final event = videos.isEmpty ? null : videos[_index % videos.length];
    final controller = _current;
    final ready = controller != null && controller.value.isInitialized;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEvents(videos),
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final signal = velocity.abs() > 120 ? velocity : _dragDx;
        if (signal.abs() < 12) return;
        AppHaptics.selection();
        unawaited(_manualAdvance(signal < 0 ? 1 : -1));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF080A0F)),
            if (ready)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                reverseDuration: const Duration(milliseconds: 420),
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
                        scale: Tween<double>(
                          begin: 1.025,
                          end: 1,
                        ).animate(curved),
                        child: child,
                      ),
                    ),
                  );
                },
                child: _CoverVideo(
                  key: ValueKey(event?.videoUrl ?? _index),
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
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      )
                    : const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Colors.white,
                        ),
                      ),
              ),
            const DecoratedBox(
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
            Positioned(
              left: 14,
              top: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
            Positioned(
              right: 10,
              top: 8,
              child: IconButton(
                tooltip: soundOn ? 'Mute' : 'Sound on',
                onPressed: ready ? _toggleSound : null,
                icon: Icon(
                  soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            Positioned(
              left: 15,
              right: 15,
              bottom: 15,
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
                        const SizedBox(height: 4),
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
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
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
