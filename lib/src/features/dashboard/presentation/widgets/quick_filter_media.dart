import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/quick_filter_rotate_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart';
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
  static double _activeVisibility = 0;
  static final Map<String, _QuickFilterMediaState> _handoffStates =
      <String, _QuickFilterMediaState>{};

  static void registerHandoffState(_QuickFilterMediaState state) {
    final category = state.widget.handoffCategoryId;
    if (category == null || category.isEmpty) return;
    _handoffStates[category] = state;
  }

  static void unregisterHandoffState(
    _QuickFilterMediaState state, {
    String? category,
  }) {
    final key = category ?? state.widget.handoffCategoryId;
    if (key == null || !identical(_handoffStates[key], state)) return;
    _handoffStates.remove(key);
  }

  static bool activate(_QuickFilterMediaState state, double visibility) {
    if (identical(_active, state)) {
      _activeVisibility = visibility;
      return true;
    }

    // If two dashboard cards are both partly visible, keep the card that is
    // most visible instead of letting build/listener order decide who plays.
    if (_active != null && visibility + 0.04 < _activeVisibility) return false;

    final previous = _active;
    _active = state;
    _activeVisibility = visibility;
    previous?._pauseForCoordinator(releaseOwnership: false);
    return true;
  }

  static bool owns(_QuickFilterMediaState state) => identical(_active, state);

  static void release(_QuickFilterMediaState state) {
    if (!identical(_active, state)) return;
    _active = null;
    _activeVisibility = 0;
  }

  static void pauseActive() {
    final previous = _active;
    _active = null;
    _activeVisibility = 0;
    previous?._pauseForCoordinator(releaseOwnership: false);
  }

  static SwipeDeckMediaHandoffData? captureActiveForDeck(
    bool wantSound, {
    String? categoryId,
  }) {
    if (categoryId != null) {
      final targeted = _handoffStates[categoryId];
      if (targeted == null) return null;
      return targeted._captureForDeckHandoff(
        wantSound,
        requireOwnership: false,
      );
    }

    final state = _active;
    if (state == null) return null;
    return state._captureForDeckHandoff(wantSound);
  }
}

/// Called before opening another media surface so the dashboard can never keep
/// an audible player alive underneath the destination route. This deliberately
/// does not change the shared sound preference.
void pauseQuickFilterVideoPlayback() => _VideoPlaybackCoordinator.pauseActive();

/// Transfers the active quick-filter player into [SwipeDeckMediaHandoff] so the
/// swipe deck can adopt the same initialized controller on the user's tap.
SwipeDeckMediaHandoffData? captureQuickFilterVideoForDeck({
  required bool wantSound,
  String? categoryId,
}) => _VideoPlaybackCoordinator.captureActiveForDeck(
  wantSound,
  categoryId: categoryId,
);

class QuickFilterMedia extends ConsumerStatefulWidget {
  const QuickFilterMedia({
    super.key,
    required this.sources,
    this.rotateSlot = 0,
    this.slotCount = 1,
    this.showMute = true,
    this.enableVideo = true,
    this.sourceListingIds = const <String, String>{},
    this.handoffCategoryId,
  });

  final List<String> sources;
  final int rotateSlot;
  final int slotCount;
  final bool showMute;
  final bool enableVideo;

  /// When a dashboard category is showing real listing videos, map each video
  /// URL back to its listing so a tap can continue the exact same movie in the
  /// swipe deck, just like the Events teaser handoff.
  final Map<String, String> sourceListingIds;
  final String? handoffCategoryId;

  @override
  ConsumerState<QuickFilterMedia> createState() => _QuickFilterMediaState();
}

class _QuickFilterMediaState extends ConsumerState<QuickFilterMedia>
    with WidgetsBindingObserver {
  int _index = 0;
  late List<String> _pool;
  VideoPlayerController? _video;
  String? _boundVideoUrl;
  double _dragDx = 0;
  bool _holdsBudgetSlot = false;
  bool _binding = false;
  bool _routeActive = true;
  bool _appActive = true;
  bool _videoPreviewEnabled = true;
  bool _userPaused = false;
  bool _lastReportedPlaying = false;
  double _visibleFraction = 0;
  ScrollPosition? _scrollPosition;
  bool _visibilityCheckScheduled = false;

  bool get _videoEnabled => widget.enableVideo && _videoPreviewEnabled;
  bool get _canPlay => _routeActive && _appActive && _videoEnabled;
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
    WidgetsBinding.instance.addObserver(this);
    _VideoPlaybackCoordinator.registerHandoffState(this);
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
    if (oldWidget.handoffCategoryId != widget.handoffCategoryId) {
      _VideoPlaybackCoordinator.unregisterHandoffState(
        this,
        category: oldWidget.handoffCategoryId,
      );
      _VideoPlaybackCoordinator.registerHandoffState(this);
    }
    if (!listEquals(oldWidget.sources, widget.sources) ||
        oldWidget.enableVideo != widget.enableVideo) {
      _reshuffle(widget.sources);
      _disposeVideo();
      _scheduleVisibilityCheck();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appActive = true;
        _scheduleVisibilityCheck();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appActive = false;
        _video?.setVolume(0);
        _video?.pause();
        _VideoPlaybackCoordinator.release(this);
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _VideoPlaybackCoordinator.unregisterHandoffState(this);
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

  void _togglePlayPause() {
    AppHaptics.selection();

    if (!_videoPreviewEnabled) {
      setState(() {
        _videoPreviewEnabled = true;
        _userPaused = false;
      });
      unawaited(_syncVideo(autoPlay: true));
      _scheduleVisibilityCheck();
      return;
    }

    final player = _video;
    if (player == null || !player.value.isInitialized) {
      _userPaused = false;
      unawaited(_syncVideo(autoPlay: true));
      return;
    }

    if (player.value.isPlaying) {
      player.pause();
      setState(() => _userPaused = true);
      return;
    }

    setState(() => _userPaused = false);
    unawaited(_playIfReady());
  }

  void _toggleSound() {
    AppHaptics.selection();
    unlockDeckMedia();
    final nextSoundOn = !ref.read(deckSoundOnProvider);
    ref.read(deckSoundOnProvider.notifier).setSoundOn(nextSoundOn);
    _onSoundChanged(nextSoundOn);
    if (_videoEnabled &&
        _routeActive &&
        nextSoundOn &&
        _visibleFraction >= 0.50 &&
        !_userPaused) {
      unawaited(_playIfReady());
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
    if (!_routeActive || !_appActive) {
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
      if (_VideoPlaybackCoordinator.activate(this, fraction)) {
        unawaited(_playIfReady());
      } else {
        _pauseForCoordinator();
      }
    } else {
      _pauseForCoordinator();
    }

    if (fraction <= 0.02 && _video != null) {
      _disposeVideo();
    }
  }

  void _pauseForCoordinator({bool releaseOwnership = true}) {
    final player = _video;
    if (player != null && player.value.isInitialized) {
      unawaited(player.setVolume(0));
      if (player.value.isPlaying) unawaited(player.pause());
    }
    if (releaseOwnership) _VideoPlaybackCoordinator.release(this);
  }

  String? _listingIdForUrl(String url) {
    final normalized = url.trim();
    for (final entry in widget.sourceListingIds.entries) {
      if (entry.key.trim() == normalized) return entry.value;
    }
    return null;
  }

  SwipeDeckMediaHandoffData? _captureForDeckHandoff(
    bool wantSound, {
    bool requireOwnership = true,
  }) {
    if (requireOwnership && !_VideoPlaybackCoordinator.owns(this)) return null;

    final player = _video;
    final url = _boundVideoUrl?.trim();
    if (player == null || url == null || url.isEmpty) return null;
    if (!player.value.isInitialized) return null;

    _detachPlayerListener(player);
    if (_VideoPlaybackCoordinator.owns(this)) {
      // Transfer the exact playing movie without pausing it.
      _VideoPlaybackCoordinator.release(this);
    } else {
      // A different dashboard card may own audio. Silence it before the
      // destination route starts, but keep this targeted decoded frame intact.
      _VideoPlaybackCoordinator.pauseActive();
    }
    if (_holdsBudgetSlot) {
      _VideoBudget.release();
      _holdsBudgetSlot = false;
    }
    _video = null;
    _boundVideoUrl = null;
    _binding = false;
    _userPaused = false;

    return SwipeDeckMediaHandoffData(
      videoUrl: url,
      position: player.value.position,
      controller: player,
      wantSound: wantSound,
      listingId: _listingIdForUrl(url),
      categoryId: widget.handoffCategoryId,
    );
  }

  Future<void> _playIfReady() async {
    if (!_canPlay || _userPaused || _visibleFraction < 0.50) return;

    if (!_VideoPlaybackCoordinator.activate(this, _visibleFraction)) {
      _pauseForCoordinator();
      return;
    }

    final player = _video;
    if (player == null || !player.value.isInitialized) {
      await _syncVideo(autoPlay: true);
      return;
    }
    if (!_VideoPlaybackCoordinator.owns(this)) return;

    final soundOn = ref.read(deckSoundOnProvider);
    final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
    final wantSound = soundOn && (unlocked || !kIsWeb);

    try {
      await player.setVolume(wantSound ? 1 : 0);
      if (!_VideoPlaybackCoordinator.owns(this)) {
        await player.setVolume(0);
        return;
      }
      await player.play();
      if (!_VideoPlaybackCoordinator.owns(this)) {
        await player.setVolume(0);
        await player.pause();
      }
    } catch (_) {
      // A stale asynchronous play must never revive a previous dashboard card.
      if (!_VideoPlaybackCoordinator.owns(this)) {
        try {
          await player.setVolume(0);
          await player.pause();
        } catch (_) {}
        return;
      }
      // If a browser rejects audible autoplay, keep the one owner moving muted.
      if (kIsWeb && wantSound) {
        try {
          await player.setVolume(0);
          if (_VideoPlaybackCoordinator.owns(this)) await player.play();
        } catch (_) {}
      }
    }
  }

  void _onPlayerTick() {
    final playing = _video?.value.isPlaying ?? false;
    if (playing == _lastReportedPlaying || !mounted) return;
    _lastReportedPlaying = playing;
    setState(() {});
  }

  void _attachPlayerListener(VideoPlayerController player) {
    player.removeListener(_onPlayerTick);
    _lastReportedPlaying = player.value.isPlaying;
    player.addListener(_onPlayerTick);
  }

  void _detachPlayerListener(VideoPlayerController? player) {
    player?.removeListener(_onPlayerTick);
    _lastReportedPlaying = false;
  }

  void _disposeVideo() {
    _detachPlayerListener(_video);
    _VideoPlaybackCoordinator.release(this);
    if (_holdsBudgetSlot) {
      _VideoBudget.release();
      _holdsBudgetSlot = false;
    }
    _video?.dispose();
    _video = null;
    _boundVideoUrl = null;
    _binding = false;
    _userPaused = false;
  }

  Widget _mediaControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(132),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(48)),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  void _advance(int delta) {
    if (_sources.length <= 1 || !mounted || !_routeActive) return;
    setState(() {
      _index = (_index + delta) % _sources.length;
      if (_index < 0) _index += _sources.length;
      _userPaused = false;
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
    if (previous != null) {
      _detachPlayerListener(previous);
      try {
        await previous.setVolume(0);
        if (previous.value.isPlaying) await previous.pause();
      } catch (_) {}
    }
    final next = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _video = next;

    try {
      await next.initialize();
      if (!mounted ||
          !_routeActive ||
          !_videoEnabled ||
          _boundVideoUrl != url) {
        await next.setVolume(0);
        await next.dispose();
        return;
      }
      await next.setLooping(true);
      await next.setVolume(0);
      _attachPlayerListener(next);
      if (autoPlay && _visibleFraction >= 0.50) {
        _VideoPlaybackCoordinator.activate(this, _visibleFraction);
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
    if (_canPlay && _visibleFraction >= 0.50) {
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

      // Never flash a random neighboring photo before a video is decoded.
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
    final player = _video;
    final videoPlaying =
        _videoPreviewEnabled &&
        player != null &&
        player.value.isInitialized &&
        player.value.isPlaying;
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _dragDx = 0,
            onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final gesture = velocity.abs() >= 100 ? velocity : _dragDx;
              if (_sources.length > 1 &&
                  (gesture.abs() >= 8 || _dragDx.abs() >= 8)) {
                AppHaptics.selection();
                _advance(gesture < 0 ? 1 : -1);
              }
              _dragDx = 0;
            },
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: kIsWeb ? 80 : 110),
              child: KeyedSubtree(
                key: ValueKey('${_videoEnabled ? 'video' : 'still'}:$current'),
                child: _buildMedia(current),
              ),
            ),
          ),
        ),
        if (sources.length > 1)
          Positioned(
            top: 10,
            left: 10,
            right: 52,
            child: IgnorePointer(
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
          ),
        if (widget.showMute || (widget.enableVideo && _hasVideo))
          Positioned(
            bottom: 6,
            right: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showMute)
                  _mediaControlButton(
                    icon: soundOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    onTap: _toggleSound,
                  ),
                if (widget.showMute && widget.enableVideo && _hasVideo)
                  const SizedBox(height: 6),
                if (widget.enableVideo && _hasVideo)
                  _mediaControlButton(
                    icon: videoPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onTap: _togglePlayPause,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
