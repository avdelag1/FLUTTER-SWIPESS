from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing patch target: {label}")
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, repl: str, label: str, flags: int = 0) -> str:
    updated, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"missing/ambiguous patch target: {label} ({count})")
    return updated


# ---------------------------------------------------------------------------
# 1) Handoff can carry a controller that is already initializing. This lets a
# cold dashboard tap start the network request BEFORE the full-screen deck
# paints, without reconnecting to the same URL after navigation.
# ---------------------------------------------------------------------------
p = 'lib/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart'
s = read(p)
s = replace_once(
    s,
    """    required this.position,\n    this.controller,\n    this.wantSound = false,\n""",
    """    required this.position,\n    this.controller,\n    this.preparation,\n    this.wantSound = false,\n""",
    'handoff preparation constructor',
)
s = replace_once(
    s,
    """  final VideoPlayerController? controller;\n  final bool wantSound;\n""",
    """  final VideoPlayerController? controller;\n\n  /// Optional in-flight initialization started by the dashboard tap. The deck\n  /// awaits this SAME controller instead of constructing a second network\n  /// player, so a cold video still begins loading before the route paints.\n  final Future<void>? preparation;\n  final bool wantSound;\n""",
    'handoff preparation field',
)
write(p, s)


# ---------------------------------------------------------------------------
# 2) Quick filters: taps are the navigation model (left / center / right), not
# horizontal swipes. Preserve photo aspect ratio and make video handoff work
# even when the dashboard decoder was not warm yet.
# ---------------------------------------------------------------------------
p = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
s = read(p)
s = s.replace("  double _dragDx = 0;\n", "", 1)

old_capture = r'''  SwipeDeckMediaHandoffData? _captureForDeckHandoff({
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
'''
new_capture = r'''  SwipeDeckMediaHandoffData? _captureForDeckHandoff({
    bool requireOwnership = true,
  }) {
    if (requireOwnership && !_VideoPlaybackCoordinator.owns(this)) return null;
    if (_sources.isEmpty) return null;

    final current = _sources[_index % _sources.length].trim();
    if (current.isEmpty || !_isKnownVideoUrl(current)) return null;
    final listingId = _listingIdForUrl(current);
    if (listingId == null || listingId.isEmpty) return null;

    // Best path: move the exact initialized dashboard player into the deck.
    // Do NOT pause it and do NOT seek it back later; its playhead keeps moving
    // through the zero-duration route transition exactly like Events.
    final existing = _video;
    if (existing != null &&
        existing.value.isInitialized &&
        _boundVideoUrl?.trim() == current) {
      _detachPlayerListener(existing);
      final position = existing.value.position;
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
        videoUrl: current,
        position: position,
        controller: existing,
        wantSound: _soundOn && (_mediaUnlocked || !kIsWeb),
        listingId: listingId,
        categoryId: widget.handoffCategoryId,
      );
    }

    // Cold path: immediately begin initializing ONE controller in the dashboard
    // tap gesture, then hand that same in-flight controller to the deck. This is
    // the missing Instagram-style behavior: navigation never waits, but video
    // networking also never waits for the destination widget to be built.
    _disposeVideo();
    _VideoPlaybackCoordinator.pauseActive();
    final uri = Uri.tryParse(current);
    if (uri == null) return null;
    final player = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    final preparation = () async {
      await player.initialize();
      await player.setLooping(true);
      await player.setVolume(0);
    }();

    return SwipeDeckMediaHandoffData(
      videoUrl: current,
      position: Duration.zero,
      controller: player,
      preparation: preparation,
      wantSound: _soundOn && (_mediaUnlocked || !kIsWeb),
      listingId: listingId,
      categoryId: widget.handoffCategoryId,
    );
  }
'''
s = replace_once(s, old_capture, new_capture, 'cold + live video handoff')

# Never pass both cacheWidth and cacheHeight to the image decoder: doing so can
# resample the source into the card aspect before BoxFit.cover crops it.
s = replace_once(
    s,
    """        final cacheW = (logicalW * dpr).round().clamp(480, 1440).toInt();\n        final cacheH = (logicalH * dpr).round().clamp(640, 1920).toInt();\n        return Image.network(\n          url,\n          fit: BoxFit.cover,\n          width: double.infinity,\n          height: double.infinity,\n          cacheWidth: cacheW,\n          cacheHeight: cacheH,\n""",
    """        final cacheW = (logicalW * dpr).round().clamp(480, 1440).toInt();\n        return Image.network(\n          url,\n          fit: BoxFit.cover,\n          alignment: Alignment.center,\n          width: double.infinity,\n          height: double.infinity,\n          cacheWidth: cacheW,\n""",
    'quick-filter preserve source aspect ratio',
)

# Left/right TAP is the easy media navigation. Keep a generous center zone that
# ALWAYS opens the exact listing, including video listings. Remove drag handlers
# so a slightly moving finger cannot steal the intended tap.
s = replace_once(
    s,
    """                if (x <= width * .34) {\n                  AppHaptics.selection();\n                  _advance(-1);\n                  return;\n                }\n                if (x >= width * .66) {\n                  AppHaptics.selection();\n                  _advance(1);\n                  return;\n                }\n              }\n              widget.onOpen?.call(_listingIdForUrl(current));\n            },\n            onHorizontalDragStart: (_) => _dragDx = 0,\n            onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,\n            onHorizontalDragEnd: (details) {\n              final velocity = details.primaryVelocity ?? 0;\n              final gesture = velocity.abs() >= 100 ? velocity : _dragDx;\n              if (_sources.length > 1 &&\n                  (gesture.abs() >= 8 || _dragDx.abs() >= 8)) {\n                AppHaptics.selection();\n                _advance(gesture < 0 ? 1 : -1);\n              }\n              _dragDx = 0;\n            },\n""",
    """                if (x <= width * .30) {\n                  AppHaptics.selection();\n                  _advance(-1);\n                  return;\n                }\n                if (x >= width * .70) {\n                  AppHaptics.selection();\n                  _advance(1);\n                  return;\n                }\n              }\n              // Center 40% is a guaranteed open target for BOTH photos and\n              // videos. Listing identity is resolved from the exact media now\n              // on screen, so a video can never become an unopenable card.\n              widget.onOpen?.call(_listingIdForUrl(current));\n            },\n""",
    'tap-only quick-filter navigation',
)
write(p, s)


# ---------------------------------------------------------------------------
# 3) Full listing card: preserve source image aspect ratio, await an in-flight
# handoff controller, never seek a controller that is still playing, and expose
# a clear play/pause control beside mute.
# ---------------------------------------------------------------------------
p = 'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart'
s = read(p)

s = replace_once(
    s,
    """      cacheWidth: _cacheWidth(context),\n      cacheHeight: _cacheHeight(context),\n""",
    """      cacheWidth: _cacheWidth(context),\n""",
    'full card preserve source aspect ratio',
)

# Expand the protected top-right hit zone for Mute + Play/Pause (+ Undo).
s = replace_once(
    s,
    """    final topRight = widget.canUndo && widget.onUndo != null ? 92.0 : 52.0;\n""",
    """    final topRight = widget.canUndo && widget.onUndo != null ? 136.0 : 96.0;\n""",
    'video controls hit zone',
)

# Add explicit play/pause method before hold handling.
s = replace_once(
    s,
    """  void _cancelHold() {\n""",
    """  Future<void> _toggleVideoPlayback() async {\n    AppHaptics.selection();\n    final player = _video;\n    if (player == null || !player.value.isInitialized) {\n      await _syncVideo();\n      return;\n    }\n    if (player.value.isPlaying) {\n      try {\n        await player.pause();\n      } catch (_) {}\n      await _soundtrack.stop();\n      if (mounted) setState(() {});\n      return;\n    }\n    await _applyPlaybackRole(player);\n    if (mounted) setState(() {});\n  }\n\n  void _cancelHold() {\n""",
    'explicit play pause method',
)

# The transferred dashboard player may still be advancing. Never seek that same
# live controller back to the stale capture timestamp. A cold/in-flight player
# awaits its already-started preparation instead of reconnecting.
old_handoff = r'''    final handoff = SwipeDeckMediaHandoff.take();
    if (handoff != null) {
      final handedUrl = handoff.videoUrl.trim();
      if (handedUrl == url.trim() && handoff.controller != null) {
        if (handoff.wantSound) {
          ref.read(deckSoundOnProvider.notifier).preserveAudibleHandoff();
        }
        final controller = handoff.controller!;
        if (handoff.position > Duration.zero) {
          try {
            await controller.seekTo(handoff.position);
          } catch (_) {}
        }
        await _adoptPreparedVideo(url, controller);
        return;
      }
      unawaited(handoff.controller?.dispose());
    }
'''
new_handoff = r'''    final handoff = SwipeDeckMediaHandoff.take();
    if (handoff != null) {
      final handedUrl = handoff.videoUrl.trim();
      if (handedUrl == url.trim() && handoff.controller != null) {
        if (handoff.wantSound) {
          ref.read(deckSoundOnProvider.notifier).preserveAudibleHandoff();
        }
        final controller = handoff.controller!;
        try {
          await handoff.preparation;
        } catch (_) {
          unawaited(controller.dispose());
          if (mounted) setState(() {});
          return;
        }
        if (!controller.value.isInitialized) {
          unawaited(controller.dispose());
          return;
        }
        // If the dashboard movie is still playing, its playhead has continued
        // through navigation. Seeking to the old captured position would cause
        // the exact stop/jump the user reported. Only restore a timestamp when
        // the transferred player is actually paused.
        if (!controller.value.isPlaying && handoff.position > Duration.zero) {
          try {
            await controller.seekTo(handoff.position);
          } catch (_) {}
        }
        await _adoptPreparedVideo(url, controller);
        return;
      }
      unawaited(handoff.controller?.dispose());
    }
'''
s = replace_once(s, old_handoff, new_handoff, 'continuous deck video adoption')

# Build knows whether the current video is moving so the icon is truthful.
s = replace_once(
    s,
    """    final current = media.isEmpty ? null : media[_photoIndex % media.length];\n    final soundOn = ref.watch(deckSoundOnProvider);\n""",
    """    final current = media.isEmpty ? null : media[_photoIndex % media.length];\n    final currentIsVideo = current != null && _isVideo(current);\n    final videoPlaying = currentIsVideo && _video?.value.isPlaying == true;\n    final soundOn = ref.watch(deckSoundOnProvider);\n""",
    'video playing build state',
)

# Add play/pause immediately below mute. It remains separate from audio so mute
# never doubles as a hidden playback-resume action.
s = replace_once(
    s,
    """                        _MuteButton(\n                          soundOn: soundOn,\n                          onTap: () {\n                            AppHaptics.selection();\n                            unlockDeckMedia();\n                            ref.read(deckSoundOnProvider.notifier).toggle();\n                          },\n                        ),\n""",
    """                        _MuteButton(\n                          soundOn: soundOn,\n                          onTap: () {\n                            AppHaptics.selection();\n                            unlockDeckMedia();\n                            ref.read(deckSoundOnProvider.notifier).toggle();\n                          },\n                        ),\n                        if (currentIsVideo) ...[\n                          SizedBox(height: 6),\n                          _GlassCircle(\n                            size: 36,\n                            iconSize: 19,\n                            icon: videoPlaying\n                                ? Icons.pause_rounded\n                                : Icons.play_arrow_rounded,\n                            onTap: () => unawaited(_toggleVideoPlayback()),\n                          ),\n                        ],\n""",
    'listing play pause button',
)
write(p, s)


# ---------------------------------------------------------------------------
# 4) Prepared-controller stack must not reject an initializing handoff. It only
# puts initialized players in the local preload map; the top card itself awaits
# the in-flight handoff future.
# ---------------------------------------------------------------------------
p = 'lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart'
s = read(p)

s = replace_once(
    s,
    """    if (listingId == null ||\n        controller == null ||\n        !controller.value.isInitialized) {\n      // Preserve legacy/non-listing handoffs for the top card's existing path.\n      SwipeDeckMediaHandoff.set(handoff);\n      return;\n    }\n""",
    """    if (listingId == null || controller == null) {\n      // Preserve legacy/non-listing handoffs for the top card's existing path.\n      SwipeDeckMediaHandoff.set(handoff);\n      return;\n    }\n""",
    'accept initializing dashboard controller',
)

s = replace_once(
    s,
    """    _cursor = target;\n    _preloadedVideos[listingId] = controller;\n    // Keep the metadata beside the same controller until the top card consumes\n""",
    """    _cursor = target;\n    if (controller.value.isInitialized) {\n      _preloadedVideos[listingId] = controller;\n    }\n    // Keep the metadata beside the same controller until the top card consumes\n""",
    'only cache initialized handoff',
)

# Image prefetch should constrain only one dimension so original ratios survive
# the decode cache just as they do on the visible card.
s = sub_once(
    s,
    r"\n  int _cacheHeight\(\) =>.*?\.toInt\(\);\n",
    "\n",
    'remove forced cache height',
    flags=re.S,
)
s = replace_once(
    s,
    """  void _precacheUrl(String raw, int width, int height) {\n""",
    """  void _precacheUrl(String raw, int width) {\n""",
    'prefetch width only signature',
)
s = replace_once(
    s,
    """    final provider = ResizeImage.resizeIfNeeded(\n      width,\n      height,\n      NetworkImage(url),\n    );\n""",
    """    final provider = ResizeImage.resizeIfNeeded(\n      width,\n      null,\n      NetworkImage(url),\n    );\n""",
    'prefetch preserve ratio',
)
s = s.replace("      final height = _cacheHeight();\n", "")
s = s.replace("_precacheUrl(hero, width, height)", "_precacheUrl(hero, width)")
s = s.replace("_precacheUrl(url, width, height)", "_precacheUrl(url, width)")
s = s.replace("_precacheUrl(images[index], width, height)", "_precacheUrl(images[index], width)")
write(p, s)


# Small wording cleanup: the dashboard card interaction is now intentionally
# tap-only, so future patches do not reintroduce a conflicting swipe gesture.
p = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
s = read(p)
s = s.replace(
    "// Body taps/swipes are handled inside QuickFilterMedia so edge\n              // navigation and center-open never fight an opaque overlay.",
    "// Body taps are handled inside QuickFilterMedia: left/right change media\n              // and the center always opens the exact listing.",
    1,
)
write(p, s)
