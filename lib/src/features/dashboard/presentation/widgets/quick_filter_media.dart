import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
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

VoidCallback? _pauseDashboardEventsPreview;
VoidCallback? _resumeDashboardEventsPreview;

/// Events owns the default live dashboard player. Listing quick filters can
/// temporarily take that playback slot without allowing two videos to run at
/// once. The hooks stay in-memory only and are cleared with the widget.
void registerDashboardEventsPlaybackHooks({
  required VoidCallback pause,
  required VoidCallback resume,
}) {
  _pauseDashboardEventsPreview = pause;
  _resumeDashboardEventsPreview = resume;
}

void unregisterDashboardEventsPlaybackHooks({
  required VoidCallback pause,
  required VoidCallback resume,
}) {
  if (identical(_pauseDashboardEventsPreview, pause)) {
    _pauseDashboardEventsPreview = null;
  }
  if (identical(_resumeDashboardEventsPreview, resume)) {
    _resumeDashboardEventsPreview = null;
  }
}

class _VideoBudget {
  // Keep decoder pressure deliberately tiny. Events has its own live player,
  // so letting ten listing controllers sit around was enough to make web/PWA
  // and older phones stutter badly. Two web previews / three native previews
  // are enough to show real paused frames without turning the dashboard into a
  // wall of active decoders.
  static int get maxActive => 4;
  static final Set<_QuickFilterMediaState> _holders =
      <_QuickFilterMediaState>{};

  static bool tryAcquire(
    _QuickFilterMediaState state, {
    bool priority = false,
  }) {
    if (_holders.contains(state)) return true;

    // A user pressing Play always wins over an idle preview. Evict one paused
    // preview instead of making the tap appear broken because the tiny decoder
    // budget happened to be full.
    if (_holders.length >= maxActive && priority) {
      final candidates = List<_QuickFilterMediaState>.of(_holders);
      for (final candidate in candidates) {
        if (candidate._manualPlaybackStarted ||
            _VideoPlaybackCoordinator.owns(candidate)) {
          continue;
        }
        candidate._disposeVideo();
        break;
      }
    }

    if (_holders.length >= maxActive) return false;
    _holders.add(state);
    return true;
  }

  static void release(_QuickFilterMediaState state) {
    _holders.remove(state);
  }
}

class _VideoPlaybackCoordinator {
  // Manual quick-filter players are independent. Track every active card so
  // one card's Play/Mute controls never change another card's media state.
  static final Set<_QuickFilterMediaState> _activeStates =
      <_QuickFilterMediaState>{};
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
    // A dashboard can show several video-capable cards at once, but only one
    // controller may advance frames. A deliberate Play immediately silences
    // the previous listing card and the continuously-running Events teaser.
    final previous = List<_QuickFilterMediaState>.of(_activeStates);
    for (final candidate in previous) {
      if (identical(candidate, state)) continue;
      candidate._pauseForCoordinator(releaseOwnership: false);
    }
    _activeStates
      ..clear()
      ..add(state);
    _pauseDashboardEventsPreview?.call();
    return true;
  }

  static bool owns(_QuickFilterMediaState state) =>
      _activeStates.contains(state);

  static void release(
    _QuickFilterMediaState state, {
    bool resumeEventsWhenIdle = true,
  }) {
    _activeStates.remove(state);
    if (resumeEventsWhenIdle && _activeStates.isEmpty) {
      _resumeDashboardEventsPreview?.call();
    }
  }

  static void pauseActive({bool resumeEventsWhenIdle = false}) {
    final active = List<_QuickFilterMediaState>.of(_activeStates);
    _activeStates.clear();
    for (final state in active) {
      state._pauseForCoordinator(releaseOwnership: false);
    }
    if (resumeEventsWhenIdle) _resumeDashboardEventsPreview?.call();
  }

  static SwipeDeckMediaHandoffData? captureActiveForDeck({String? categoryId}) {
    if (categoryId != null) {
      final targeted = _handoffStates[categoryId];
      if (targeted == null) return null;
      return targeted._captureForDeckHandoff(requireOwnership: false);
    }

    if (_activeStates.isEmpty) return null;
    return _activeStates.last._captureForDeckHandoff();
  }
}

/// Called before opening another media surface so the dashboard can never keep
/// an audible player alive underneath the destination route. This deliberately
/// does not change the shared sound preference.
void pauseQuickFilterVideoPlayback() => _VideoPlaybackCoordinator.pauseActive();

/// Transfers the active quick-filter player into [SwipeDeckMediaHandoff] so the
/// swipe deck can adopt the same initialized controller on the user's tap.
SwipeDeckMediaHandoffData? captureQuickFilterVideoForDeck({
  String? categoryId,
}) => _VideoPlaybackCoordinator.captureActiveForDeck(categoryId: categoryId);

class QuickFilterMedia extends ConsumerStatefulWidget {
  const QuickFilterMedia({
    super.key,
    required this.sources,
    this.rotateSlot = 0,
    this.slotCount = 1,
    this.showMute = true,
    this.enableVideo = true,
    this.sourceListingIds = const <String, String>{},
    this.sourceImageListingIds = const <String, String>{},
    this.videoPosterUrls = const <String, String>{},
    this.handoffCategoryId,
    this.onOpen,
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
  final Map<String, String> sourceImageListingIds;
  final Map<String, String> videoPosterUrls;
  final String? handoffCategoryId;
  final ValueChanged<String?>? onOpen;

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
  bool _userPaused = true;
  bool _manualPlaybackStarted = false;
  bool _lastReportedPlaying = false;
  bool _reportedVideoTurnComplete = false;
  bool _soundOn = false;
  bool _mediaUnlocked = false;
  double _visibleFraction = 0;
  ScrollPosition? _scrollPosition;
  bool _visibilityCheckScheduled = false;
  bool _previewWarmupScheduled = false;

  double get _previewWarmupThreshold => kIsWeb ? 0.12 : 0.10;

  bool get _videoEnabled => widget.enableVideo && _videoPreviewEnabled;
  bool get _canPlay =>
      _routeActive &&
      _appActive &&
      _videoEnabled &&
      _manualPlaybackStarted &&
      !_userPaused;
  bool _isKnownVideoUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return false;
    // `videoUrl` is authoritative. Supabase/CDN URLs are not required to keep
    // a file extension, so never demote a real uploaded movie to an image just
    // because its public URL is extensionless.
    for (final url in widget.sourceListingIds.keys) {
      if (url.trim() == normalized) return true;
    }
    return isQuickFilterVideoUrl(normalized);
  }

  bool get _hasVideo => _pool.any(_isKnownVideoUrl);

  int get _rotateSlotCount => widget.slotCount.clamp(1, 64).toInt();

  List<String> get _sources {
    if (_pool.isEmpty) return const <String>[];
    if (_videoEnabled) return _pool;
    final stills = _pool
        .where((u) => !_isKnownVideoUrl(u))
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

    if (_sources.isEmpty) return;
    final current = _sources[_index % _sources.length];
    if (!_isKnownVideoUrl(current)) {
      final videoIndex = _sources.indexWhere(_isKnownVideoUrl);
      if (videoIndex < 0) return;
      _disposeVideo();
      setState(() {
        _index = videoIndex;
        _reportedVideoTurnComplete = false;
      });
    }

    final player = _video;
    if (player != null &&
        player.value.isInitialized &&
        player.value.isPlaying) {
      unawaited(player.pause());
      setState(() {
        _userPaused = true;
        _manualPlaybackStarted = false;
      });
      ref
          .read(quickFilterRotateTickProvider.notifier)
          .resumeAfterManualVideo(
            slot: widget.rotateSlot,
            slotCount: _rotateSlotCount,
          );
      _VideoPlaybackCoordinator.release(this);
      return;
    }

    // Claim the one dashboard playback slot synchronously on the user's tap.
    // This silences Events/another listing before video initialization starts,
    // so two streams can never overlap while a network player warms up.
    _VideoPlaybackCoordinator.activate(this, _visibleFraction);

    setState(() {
      _videoPreviewEnabled = true;
      _userPaused = false;
      _manualPlaybackStarted = true;
    });
    ref
        .read(quickFilterRotateTickProvider.notifier)
        .pauseForManualVideo(
          slot: widget.rotateSlot,
          slotCount: _rotateSlotCount,
        );
    unawaited(_syncVideo(autoPlay: true));
    _scheduleVisibilityCheck();
  }

  void _toggleSound() {
    AppHaptics.selection();
    // Browser media unlock is only a gesture capability. The actual sound
    // preference remains LOCAL to this exact quick-filter card. Never write a
    // shared deck/event sound provider from here.
    unlockDeckMedia();
    final nextSoundOn = !_soundOn;
    if (nextSoundOn) _mediaUnlocked = true;
    setState(() => _soundOn = nextSoundOn);
    _onSoundChanged(nextSoundOn);
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
    _visibleFraction = render.size.height <= 0
        ? 0.0
        : visibleHeight / render.size.height;

    if (_sources.isEmpty) return;
    final current = _sources[_index % _sources.length];
    if (!_videoEnabled || !_isKnownVideoUrl(current)) {
      _pauseForCoordinator();
      return;
    }

    // Non-Events videos remain manual-only, but a visible video listing now
    // warms one paused controller so the card shows the REAL decoded movie
    // frame instead of looking like another photo. This also makes Play feel
    // instant because initialization has already happened.
    if (!_manualPlaybackStarted || _userPaused) {
      if (_visibleFraction >= _previewWarmupThreshold) {
        _schedulePreviewWarmup();
      } else if (_visibleFraction <= 0.06 && _video != null) {
        // Release decoders as soon as a card is truly off-screen. This is the
        // main guardrail that keeps scrolling and Events playback smooth.
        _disposeVideo();
      } else {
        final player = _video;
        if (player != null && player.value.isInitialized) {
          unawaited(player.setVolume(0));
          if (player.value.isPlaying) unawaited(player.pause());
        }
        _VideoPlaybackCoordinator.release(this);
      }
      return;
    }

    if (_visibleFraction >= 0.50) {
      if (_VideoPlaybackCoordinator.activate(this, _visibleFraction)) {
        unawaited(_playIfReady());
      }
    } else {
      _pauseForCoordinator();
    }
  }

  void _schedulePreviewWarmup() {
    if (!mounted ||
        _previewWarmupScheduled ||
        _binding ||
        _video != null ||
        !_routeActive ||
        !_appActive) {
      return;
    }

    _previewWarmupScheduled = true;
    final stagger = widget.rotateSlot.abs() % 4;
    final delay = Duration(
      milliseconds: (kIsWeb ? 24 : 12) + stagger * (kIsWeb ? 22 : 12),
    );

    Future<void>.delayed(delay, () async {
      _previewWarmupScheduled = false;
      if (!mounted ||
          !_routeActive ||
          !_appActive ||
          _manualPlaybackStarted ||
          !_userPaused ||
          _visibleFraction < _previewWarmupThreshold ||
          _sources.isEmpty) {
        return;
      }
      final current = _sources[_index % _sources.length];
      if (!_isKnownVideoUrl(current)) return;
      await _syncVideo(autoPlay: false);
    });
  }

  void _pauseForCoordinator({bool releaseOwnership = true}) {
    final player = _video;
    if (player != null && player.value.isInitialized) {
      unawaited(player.setVolume(0));
      if (player.value.isPlaying) unawaited(player.pause());
    }
    if (_manualPlaybackStarted) {
      _manualPlaybackStarted = false;
      _userPaused = true;
      ref
          .read(quickFilterRotateTickProvider.notifier)
          .resumeAfterManualVideo(
            slot: widget.rotateSlot,
            slotCount: _rotateSlotCount,
          );
    }
    if (releaseOwnership) _VideoPlaybackCoordinator.release(this);
  }

  String? _listingIdForUrl(String url) {
    final normalized = url.trim();
    for (final entry in widget.sourceListingIds.entries) {
      if (entry.key.trim() == normalized) return entry.value;
    }
    for (final entry in widget.sourceImageListingIds.entries) {
      if (entry.key.trim() == normalized) return entry.value;
    }
    return null;
  }

  SwipeDeckMediaHandoffData? _captureForDeckHandoff({
    bool requireOwnership = true,
  }) {
    if (requireOwnership && !_VideoPlaybackCoordinator.owns(this)) return null;

    final player = _video;
    final url = _boundVideoUrl?.trim();
    if (player == null || url == null || url.isEmpty) return null;
    if (!player.value.isInitialized) return null;

    _detachPlayerListener(player);
    // Transfer this exact movie, then stop every OTHER quick-filter player so
    // no dashboard audio keeps running underneath the destination route.
    _VideoPlaybackCoordinator.release(this, resumeEventsWhenIdle: false);
    _VideoPlaybackCoordinator.pauseActive();
    if (_holdsBudgetSlot) {
      _VideoBudget.release(this);
      _holdsBudgetSlot = false;
    }
    _video = null;
    _boundVideoUrl = null;
    _binding = false;
    _userPaused = true;
    _manualPlaybackStarted = false;
    ref
        .read(quickFilterRotateTickProvider.notifier)
        .resumeAfterManualVideo(
          slot: widget.rotateSlot,
          slotCount: _rotateSlotCount,
        );

    return SwipeDeckMediaHandoffData(
      videoUrl: url,
      position: player.value.position,
      controller: player,
      wantSound: _soundOn && (_mediaUnlocked || !kIsWeb),
      listingId: _listingIdForUrl(url),
      categoryId: widget.handoffCategoryId,
    );
  }

  Future<void> _playIfReady() async {
    if (!_canPlay || _userPaused || _visibleFraction < 0.50) return;

    ref
        .read(quickFilterRotateTickProvider.notifier)
        .pauseForManualVideo(
          slot: widget.rotateSlot,
          slotCount: _rotateSlotCount,
        );

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

    final wantSound = _soundOn && (_mediaUnlocked || !kIsWeb);

    try {
      final duration = player.value.duration;
      final position = player.value.position;
      if (duration.inMilliseconds > 0 &&
          position.inMilliseconds >= duration.inMilliseconds - 180) {
        await player.seekTo(Duration.zero);
      } else if (position.inMilliseconds > 0 &&
          position.inMilliseconds <= 140) {
        // Warm previews sit on frame ~90ms. A deliberate Play starts the clip
        // from frame zero so the user never loses the opening moment.
        await player.seekTo(Duration.zero);
      }
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
    final player = _video;
    if (player == null || !mounted) return;

    final value = player.value;
    final durationMs = value.duration.inMilliseconds;
    final positionMs = value.position.inMilliseconds;
    final ended =
        durationMs > 0 && positionMs >= durationMs - 140 && !value.isPlaying;

    if (ended && _manualPlaybackStarted && !_reportedVideoTurnComplete) {
      _reportedVideoTurnComplete = true;
      _manualPlaybackStarted = false;
      _userPaused = true;
      ref
          .read(quickFilterRotateTickProvider.notifier)
          .resumeAfterManualVideo(
            slot: widget.rotateSlot,
            slotCount: _rotateSlotCount,
          );
      _VideoPlaybackCoordinator.release(this);
    }

    final playing = value.isPlaying;
    if (playing == _lastReportedPlaying) return;
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
    ref
        .read(quickFilterRotateTickProvider.notifier)
        .resumeAfterManualVideo(
          slot: widget.rotateSlot,
          slotCount: _rotateSlotCount,
        );
    _detachPlayerListener(_video);
    _VideoPlaybackCoordinator.release(this);
    if (_holdsBudgetSlot) {
      _VideoBudget.release(this);
      _holdsBudgetSlot = false;
    }
    _video?.dispose();
    _video = null;
    _boundVideoUrl = null;
    _binding = false;
    _userPaused = true;
    _manualPlaybackStarted = false;
    _reportedVideoTurnComplete = false;
    _previewWarmupScheduled = false;
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
      _userPaused = true;
      _manualPlaybackStarted = false;
      _reportedVideoTurnComplete = false;
    });
    _disposeVideo();
    _scheduleVisibilityCheck();
  }

  Future<void> _syncVideo({required bool autoPlay}) async {
    if (!_routeActive || !_videoEnabled || _binding || _sources.isEmpty) return;
    final url = _sources[_index % _sources.length];
    if (!_videoEnabled || !_isKnownVideoUrl(url)) {
      _disposeVideo();
      if (mounted) setState(() {});
      return;
    }

    if (url == _boundVideoUrl && _video != null) {
      if (autoPlay && _visibleFraction >= 0.50) await _playIfReady();
      return;
    }

    if (!_holdsBudgetSlot &&
        !_VideoBudget.tryAcquire(
          this,
          priority: autoPlay || _manualPlaybackStarted,
        )) {
      return;
    }
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
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
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
      // Dashboard listing previews play once. Their real end advances the
      // shared card sequence; looping would prevent the next card from moving.
      await next.setLooping(false);
      await next.setVolume(0);
      // Decode a real movie frame while the card is still paused. The user sees
      // the actual video preview (not a listing photo) and Play has no cold-start
      // seek/decode penalty. Keep the warm frame silent and stationary.
      if (!autoPlay && next.value.duration.inMilliseconds > 120) {
        await next.seekTo(const Duration(milliseconds: 90));
        await next.pause();
      }
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
        _VideoBudget.release(this);
        _holdsBudgetSlot = false;
      }
      _manualPlaybackStarted = false;
      _userPaused = true;
      ref
          .read(quickFilterRotateTickProvider.notifier)
          .resumeAfterManualVideo(
            slot: widget.rotateSlot,
            slotCount: _rotateSlotCount,
          );
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
      player.setVolume(soundOn && (_mediaUnlocked || !kIsWeb) ? 1 : 0);
    } else {
      player.setVolume(0);
      player.pause();
    }
  }

  String? _posterForVideo(String url) {
    final normalized = url.trim();
    for (final entry in widget.videoPosterUrls.entries) {
      if (entry.key.trim() == normalized && entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return null;
  }

  String? _fallbackStillUrl() {
    if (_pool.isEmpty) return null;

    for (var distance = 1; distance <= _pool.length; distance++) {
      final before = _pool[(_index - distance) % _pool.length];
      if (!_isKnownVideoUrl(before)) return before;

      final after = _pool[(_index + distance) % _pool.length];
      if (!_isKnownVideoUrl(after)) return after;
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
    if (_isKnownVideoUrl(url)) {
      if (!_videoEnabled) {
        final fallback = _posterForVideo(url) ?? _fallbackStillUrl();
        if (fallback != null) return _buildStill(fallback);
        return const ColoredBox(color: Color(0xFF15171C));
      }

      final player = _video;
      if (player != null &&
          player.value.isInitialized &&
          _boundVideoUrl == url) {
        final size = player.value.size;
        if (size.width > 0 && size.height > 0) {
          return ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(player),
                ),
              ),
            ),
          );
        }
      }

      final poster = _posterForVideo(url) ?? _fallbackStillUrl();
      if (poster != null) return _buildStill(poster);
      return const ColoredBox(
        color: Color(0xFF15171C),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white24,
          ),
        ),
      );
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
    final soundOn = _soundOn;
    final player = _video;
    final videoPlaying =
        _videoPreviewEnabled &&
        player != null &&
        player.value.isInitialized &&
        player.value.isPlaying;
    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {
      if (!_routeActive) return;
      final slots = _rotateSlotCount;
      final normalizedSlot = widget.rotateSlot % slots;
      final target = normalizedSlot < 0
          ? normalizedSlot + slots
          : normalizedSlot;
      if (next % slots != target) return;

      // On each round only this card changes listing. Video sources stay on
      // their static poster until the user explicitly presses Play.
      if (prev != null) _advance(1);
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
            onTapUp: (details) {
              final render = context.findRenderObject();
              final width = render is RenderBox && render.hasSize
                  ? render.size.width
                  : 0.0;
              if (_sources.length > 1 && width > 0) {
                final x = details.localPosition.dx;
                if (x <= width * .34) {
                  AppHaptics.selection();
                  _advance(-1);
                  return;
                }
                if (x >= width * .66) {
                  AppHaptics.selection();
                  _advance(1);
                  return;
                }
              }
              widget.onOpen?.call(_listingIdForUrl(current));
            },
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
                    if (i > 0) SizedBox(width: 3),
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
        if (_isKnownVideoUrl(current))
          Positioned(
            bottom: 76,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(145),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(42)),
                ),
                child: Row(
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
                  SizedBox(height: 6),
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
