import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/quick_filter_rotate_provider.dart';
import 'package:video_player/video_player.dart';

bool isQuickFilterVideoUrl(String url) {
  final lower = url.toLowerCase();
  if (lower == 'video_attachment') return true;
  return lower.contains('.mp4') ||
      lower.contains('.webm') ||
      lower.contains('.mov') ||
      lower.contains('.m4v') ||
      lower.contains('/videos/');
}

class _VideoBudget {
  static const int maxActive = 2;
  static int _active = 0;

  static bool tryAcquire() {
    if (_active >= maxActive) return false;
    _active++;
    return true;
  }

  static void release() {
    if (_active > 0) _active--;
  }
}

class _VideoPlaybackCoordinator {
  static _QuickFilterMediaState? _active;

  static void activate(_QuickFilterMediaState state) {
    if (identical(_active, state)) return;
    _active?._pauseForCoordinator();
    _active = state;
  }

  static void release(_QuickFilterMediaState state) {
    if (identical(_active, state)) _active = null;
  }
}

class QuickFilterMedia extends ConsumerStatefulWidget {
  const QuickFilterMedia({
    super.key,
    required this.sources,
    this.rotateSlot = 0,
    this.slotCount = 1,
    this.showMute = true,
    this.enableVideo = true,
  });

  final List<String> sources;
  final int rotateSlot;
  final int slotCount;
  final bool showMute;
  final bool enableVideo;

  @override
  ConsumerState<QuickFilterMedia> createState() => _QuickFilterMediaState();
}

class _QuickFilterMediaState extends ConsumerState<QuickFilterMedia> {
  int _index = 0;
  late List<String> _pool;
  VideoPlayerController? _video;
  String? _boundVideoUrl;
  double _dragDx = 0;
  bool _holdsBudgetSlot = false;
  bool _binding = false;
  bool _routeActive = true;
  bool _videoPreviewEnabled = true;
  double _visibleFraction = 0;
  ScrollPosition? _scrollPosition;
  bool _visibilityCheckScheduled = false;

  bool get _videoEnabled => widget.enableVideo && _videoPreviewEnabled;
  bool get _hasVideo => _pool.any(isQuickFilterVideoUrl);

  List<String> get _sources {
    if (_pool.isEmpty) return const <String>[];
    if (_videoEnabled) return _pool;
    final stills = _pool
        .where((u) => !isQuickFilterVideoUrl(u))
        .toList(growable: false);
    return stills.isEmpty ? _pool : stills;
  }

  @override
  void initState() {
    super.initState();
    _reshuffle(widget.sources);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleVisibilityCheck(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRouteActive = TickerMode.of(context);
    if (_routeActive != nextRouteActive) {
      _routeActive = nextRouteActive;
      if (!_routeActive) {
        _visibleFraction = 0;
        _video?.setVolume(0);
        _pauseForCoordinator();
      } else {
        _scheduleVisibilityCheck();
      }
    }
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(next, _scrollPosition)) {
      _scrollPosition?.removeListener(_scheduleVisibilityCheck);
      _scrollPosition = next;
      _scrollPosition?.addListener(_scheduleVisibilityCheck);
    }
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant QuickFilterMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.sources, widget.sources) ||
        oldWidget.enableVideo != widget.enableVideo) {
      _reshuffle(widget.sources);
      _disposeVideo();
      _scheduleVisibilityCheck();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _VideoPlaybackCoordinator.release(this);
    _disposeVideo();
    super.dispose();
  }

  void _reshuffle(List<String> sources) {
    _pool = List<String>.from(sources);
    if (_pool.length > 2) {
      // Source 0 is the art-directed hero for this category. Keep it stable so
      // the first paint is intentional, then randomize only the secondary media.
      final hero = _pool.removeAt(0);
      _pool.shuffle(
        math.Random(
          DateTime.now().microsecondsSinceEpoch ^ widget.rotateSlot * 7919,
        ),
      );
      _pool.insert(0, hero);
    }
    _index = 0;
  }

  void _toggleVideoPreview() {
    AppHaptics.selection();
    final next = !_videoPreviewEnabled;
    setState(() {
      _videoPreviewEnabled = next;
      _index = 0;
    });
    if (!next) {
      // Releasing the controller immediately saves CPU/GPU/network instead of
      // merely hiding a video that is still decoding behind the still image.
      _disposeVideo();
    } else {
      _scheduleVisibilityCheck();
    }
  }

  void _scheduleVisibilityCheck() {
    if (!mounted || !_routeActive || _visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted || !_routeActive) return;
      _updateVisibilityAndPlayback();
    });
  }

  void _updateVisibilityAndPlayback() {
    if (!_routeActive) {
      _visibleFraction = 0;
      _video?.setVolume(0);
      _pauseForCoordinator();
      return;
    }
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;

    final top = render.localToGlobal(Offset.zero).dy;
    final bottom = top + render.size.height;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final visibleHeight = (math.min(bottom, screenHeight) - math.max(top, 0.0))
        .clamp(0.0, render.size.height);
    final fraction = render.size.height <= 0
        ? 0.0
        : visibleHeight / render.size.height;
    _visibleFraction = fraction;

    if (_sources.isEmpty) return;
    final current = _sources[_index % _sources.length];
    if (!_videoEnabled || !isQuickFilterVideoUrl(current)) {
      _pauseForCoordinator();
      return;
    }

    if (fraction >= 0.15 && _video == null && !_binding) {
      _syncVideo(autoPlay: false);
    }

    if (fraction >= 0.50) {
      _VideoPlaybackCoordinator.activate(this);
      _playIfReady();
    } else {
      _pauseForCoordinator();
    }

    if (fraction <= 0.02 && _video != null) {
      _disposeVideo();
    }
  }

  void _pauseForCoordinator() {
    final player = _video;
    if (player != null && player.value.isInitialized) {
      player.setVolume(0);
      if (player.value.isPlaying) player.pause();
    }
    _VideoPlaybackCoordinator.release(this);
  }

  Future<void> _playIfReady() async {
    if (!_routeActive || !_videoEnabled || !_videoPreviewEnabled) return;
    final player = _video;
    if (player == null || !player.value.isInitialized) {
      await _syncVideo(autoPlay: true);
      return;
    }
    if (_visibleFraction < 0.50) return;
    final soundOn = ref.read(deckSoundOnProvider);
    final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
    final wantSound = soundOn && (unlocked || !kIsWeb);
    await player.setVolume(wantSound ? 1 : 0);
    await player.play();
  }

  void _disposeVideo() {
    _VideoPlaybackCoordinator.release(this);
    if (_holdsBudgetSlot) {
      _VideoBudget.release();
      _holdsBudgetSlot = false;
    }
    _video?.dispose();
    _video = null;
    _boundVideoUrl = null;
    _binding = false;
  }

  void _advance(int delta) {
    if (_sources.length <= 1 || !mounted || !_routeActive) return;
    setState(() {
      _index = (_index + delta) % _sources.length;
      if (_index < 0) _index += _sources.length;
    });
    _disposeVideo();
    _scheduleVisibilityCheck();
  }

  Future<void> _syncVideo({required bool autoPlay}) async {
    if (!_routeActive || !_videoEnabled || _binding || _sources.isEmpty) return;
    final url = _sources[_index % _sources.length];
    if (!_videoEnabled || !isQuickFilterVideoUrl(url)) {
      _disposeVideo();
      if (mounted) setState(() {});
      return;
    }

    if (url == _boundVideoUrl && _video != null) {
      if (autoPlay && _visibleFraction >= 0.50) await _playIfReady();
      return;
    }

    if (!_holdsBudgetSlot && !_VideoBudget.tryAcquire()) return;
    _holdsBudgetSlot = true;
    _binding = true;
    _boundVideoUrl = url;

    final previous = _video;
    final next = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = next;

    try {
      await next.initialize();
      if (!mounted || !_routeActive || !_videoEnabled || _boundVideoUrl != url) {
        await next.setVolume(0);
        await next.dispose();
        return;
      }
      await next.setLooping(true);
      await next.setVolume(0);
      if (autoPlay && _visibleFraction >= 0.50) {
        _VideoPlaybackCoordinator.activate(this);
        await _playIfReady();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (identical(_video, next)) {
        _video = null;
        _boundVideoUrl = null;
      }
      if (_holdsBudgetSlot) {
        _VideoBudget.release();
        _holdsBudgetSlot = false;
      }
      if (mounted) setState(() {});
    } finally {
      _binding = false;
      if (previous != null) {
        try {
          await previous.dispose();
        } catch (_) {}
      }
    }
  }

  void _onSoundChanged(bool soundOn) {
    final player = _video;
    if (player == null || !player.value.isInitialized) return;
    if (_videoEnabled && _routeActive && _visibleFraction >= 0.50) {
      final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
      player.setVolume(soundOn && (unlocked || !kIsWeb) ? 1 : 0);
    } else {
      player.setVolume(0);
      player.pause();
    }
  }

  String? _fallbackStillUrl() {
    if (_pool.isEmpty) return null;

    for (var distance = 1; distance <= _pool.length; distance++) {
      final before = _pool[(_index - distance) % _pool.length];
      if (!isQuickFilterVideoUrl(before)) return before;

      final after = _pool[(_index + distance) % _pool.length];
      if (!isQuickFilterVideoUrl(after)) return after;
    }
    return null;
  }

  Widget _localFallbackFor(String failedUrl) {
    for (final source in _pool) {
      if (source != failedUrl && source.startsWith('assets/')) {
        return Image.asset(
          source,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF15171C)),
        );
      }
    }
    return const ColoredBox(color: Color(0xFF15171C));
  }

  Widget _buildStill(String url) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF15171C)),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = MediaQuery.sizeOf(context).width;
    final cacheW = (logicalW * dpr * 0.55).round().clamp(320, 900);
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheW,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _localFallbackFor(url),
    );
  }

  Widget _buildMedia(String url) {
    if (isQuickFilterVideoUrl(url)) {
      if (!_videoEnabled) {
        final fallback = _fallbackStillUrl();
        if (fallback != null) return _buildStill(fallback);
        return const ColoredBox(color: Color(0xFF15171C));
      }

      final player = _video;
      if (player != null &&
          player.value.isInitialized &&
          _boundVideoUrl == url) {
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: player.value.size.width,
            height: player.value.size.height,
            child: VideoPlayer(player),
          ),
        );
      }

      final fallback = _fallbackStillUrl();
      if (fallback != null) return _buildStill(fallback);
      return const ColoredBox(color: Color(0xFF15171C));
    }
    return _buildStill(url);
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources;
    if (sources.isEmpty) {
      return const ColoredBox(color: Color(0xFF15171C));
    }
    final current = sources[_index % sources.length];
    final soundOn = ref.watch(deckSoundOnProvider);
    ref.listen<bool>(deckSoundOnProvider, (_, next) => _onSoundChanged(next));

    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {
      if (!_routeActive || _visibleFraction >= 0.50) return;
      final slots = widget.slotCount.clamp(1, 64);
      if (next % slots == widget.rotateSlot % slots) {
        _advance(1);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleVisibilityCheck(),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final gesture = velocity.abs() >= 100 ? velocity : _dragDx;
        if (_sources.length > 1 && (gesture.abs() >= 8 || _dragDx.abs() >= 8)) {
          AppHaptics.selection();
          _advance(gesture < 0 ? 1 : -1);
        }
        _dragDx = 0;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: kIsWeb ? 120 : 180),
            child: KeyedSubtree(
              key: ValueKey('${_videoEnabled ? 'video' : 'still'}:$current'),
              child: _buildMedia(current),
            ),
          ),
          if (sources.length > 1)
            Positioned(
              top: 10,
              left: 10,
              right: 44,
              child: Row(
                children: [
                  for (var i = 0; i < sources.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: i == _index ? 14 : 6,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? Colors.white
                            : Colors.white.withAlpha(110),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (widget.showMute || (widget.enableVideo && _hasVideo))
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.enableVideo && _hasVideo) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        AppHaptics.selection();
                        _toggleVideoPreview();
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(110),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _videoPreviewEnabled
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                    if (widget.showMute) const SizedBox(width: 6),
                  ],
                  if (widget.showMute)
                    GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                        unlockDeckMedia();
                        ref.read(deckSoundOnProvider.notifier).toggle();
                        _onSoundChanged(ref.read(deckSoundOnProvider));
                        if (_videoEnabled &&
                            _routeActive &&
                            ref.read(deckSoundOnProvider) &&
                            _visibleFraction >= 0.50) {
                          _playIfReady();
                        }
                      },
                      child: BreathingWidget(
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(110),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            soundOn
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
