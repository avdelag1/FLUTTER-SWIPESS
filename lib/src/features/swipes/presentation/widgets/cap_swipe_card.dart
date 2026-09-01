import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_match_score.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_match_meter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

/// Swipe card with fast media taps, deliberate hold-to-zoom and clean social
/// feedback. Swipe labels are small green LIKE / red NOPE text only.
class CapSwipeCard extends ConsumerStatefulWidget {
  const CapSwipeCard({
    super.key,
    required this.listing,
    required this.isTop,
    this.likeOpacity = 0,
    this.nopeOpacity = 0,
    this.railVisible = true,
    this.onBack,
    this.onUndo,
    this.canUndo = false,
    this.onInsights,
    this.onShare,
    this.onMessage,
    this.onReport,
    this.onOpenAi,
    this.onOpenMap,
    this.onSummonChrome,
    this.onPhotoIndexChanged,
    this.onZoomChanged,
    this.preparedVideoController,
    this.onPreparedVideoConsumed,
    this.deckDragging = false,
    this.prepareMedia = false,
  });

  final Listing listing;
  final bool isTop;
  final double likeOpacity;
  final double nopeOpacity;
  final bool deckDragging;
  final bool prepareMedia;
  final VideoPlayerController? preparedVideoController;
  final VoidCallback? onPreparedVideoConsumed;
  final bool railVisible;
  final VoidCallback? onBack;
  final VoidCallback? onUndo;
  final bool canUndo;
  final VoidCallback? onInsights;
  final VoidCallback? onShare;
  final VoidCallback? onMessage;
  final VoidCallback? onReport;
  final VoidCallback? onOpenAi;
  final VoidCallback? onOpenMap;
  final VoidCallback? onSummonChrome;
  final ValueChanged<int>? onPhotoIndexChanged;
  final ValueChanged<bool>? onZoomChanged;

  @override
  ConsumerState<CapSwipeCard> createState() => CapSwipeCardState();
}

class CapSwipeCardState extends ConsumerState<CapSwipeCard> {
  int _photoIndex = 0;
  bool _zoomed = false;
  Offset _zoomPan = Offset.zero;
  Offset? _pointerStart;
  Timer? _holdTimer;
  bool _holdPending = false;
  bool _movedPastCancel = false;
  VideoPlayerController? _video;
  String? _boundVideo;

  static const _holdDelay = Duration(milliseconds: 360);
  static const _zoomScale = 3.2;
  static const _cancelMovePx = 10.0;
  static const _tapMovePx = 12.0;

  List<String> get _media {
    final out = <String>[...widget.listing.images];
    final video = widget.listing.videoUrl;
    if (video != null && video.isNotEmpty && !out.contains(video))
      out.add(video);
    return out;
  }

  bool _isVideo(String value) {
    final l = value.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('/videos/');
  }

  bool get _needsVideo => widget.isTop;

  String? _heroImageUrl() {
    for (final raw in _media) {
      if (!_isVideo(raw)) return raw;
    }
    return _media.isNotEmpty ? _media.first : null;
  }

  int _cacheWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 2).round().clamp(480, 1600);

  void _precacheNeighborHero() {
    final url = _heroImageUrl();
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return;
    }
    final provider = ResizeImage.resizeIfNeeded(
      _cacheWidth(context),
      null,
      NetworkImage(url),
    );
    unawaited(precacheImage(provider, context).catchError((_) {}));
  }

  Widget _cachedCoverImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -.12),
      cacheWidth: _cacheWidth(context),
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _fallback(),
      frameBuilder: (context, child, frame, loadedSync) {
        if (loadedSync || frame != null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            _fallback(),
            child,
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.isTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_syncVideo());
      });
    } else if (widget.prepareMedia) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precacheNeighborHero();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CapSwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listing.id != widget.listing.id) {
      _photoIndex = 0;
      _endZoom();
    }
    if (widget.isTop && !oldWidget.isTop) {
      _photoIndex = 0;
    }
    if (widget.deckDragging && !oldWidget.deckDragging) {
      _cancelHold();
    }
    if (!widget.isTop && !widget.prepareMedia) {
      _disposeVideo();
    } else if (oldWidget.listing.id != widget.listing.id ||
        oldWidget.isTop != widget.isTop ||
        oldWidget.prepareMedia != widget.prepareMedia ||
        oldWidget.preparedVideoController != widget.preparedVideoController) {
      unawaited(_syncVideo());
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _disposeVideo();
    super.dispose();
  }

  void _disposeVideo() {
    final player = _video;
    _video = null;
    _boundVideo = null;
    if (player == null) return;
    unawaited(() async {
      try {
        await player.setVolume(0);
        if (player.value.isPlaying) await player.pause();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }());
  }

  Future<void> _applyPlaybackRole(VideoPlayerController player) async {
    if (!player.value.isInitialized) return;

    // Neighbor cards may be decoded/prepared for instant visual handoff, but
    // only the top card is allowed to advance frames or own audio.
    if (!widget.isTop) {
      try {
        await player.setVolume(0);
        if (player.value.isPlaying) await player.pause();
      } catch (_) {}
      return;
    }

    final soundOn = ref.read(deckSoundOnProvider);
    final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
    final wantSound = soundOn && (unlocked || !kIsWeb);
    if (wantSound) unlockDeckMedia();

    try {
      await player.setVolume(0);
      await player.play();
      if (wantSound) await player.setVolume(1);
    } catch (_) {
      try {
        await player.setVolume(0);
        await player.play();
        if (wantSound && widget.isTop) {
          try {
            await player.setVolume(1);
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  void _setPhoto(int index) {
    final media = _media;
    if (media.isEmpty) return;
    final normalized = ((index % media.length) + media.length) % media.length;
    if (normalized == _photoIndex) return;
    setState(() => _photoIndex = normalized);
    widget.onPhotoIndexChanged?.call(normalized);
    unawaited(_syncVideo());
  }

  Future<void> _adoptPreparedVideo(
    String url,
    VideoPlayerController prepared,
  ) async {
    final previous = _video;
    _video = prepared;
    _boundVideo = url;
    widget.onPreparedVideoConsumed?.call();
    try {
      await prepared.setLooping(true);
      await _applyPlaybackRole(prepared);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      if (previous != null && previous != prepared) {
        await previous.dispose();
      }
    }
  }

  Future<void> _syncVideo() async {
    if (!widget.isTop) {
      _disposeVideo();
      return;
    }
    final media = _media;
    if (media.isEmpty) return;
    final url = media[_photoIndex % media.length];
    if (!_isVideo(url)) {
      if (_video != null) _disposeVideo();
      return;
    }

    final handoff = SwipeDeckMediaHandoff.take();
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

    if (_boundVideo == url && _video != null) {
      await _applyPlaybackRole(_video!);
      return;
    }

    final prepared = widget.preparedVideoController;
    if (prepared != null && prepared.value.isInitialized) {
      await _adoptPreparedVideo(url, prepared);
      return;
    }

    final previous = _video;
    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = next;
    _boundVideo = url;
    try {
      await next.initialize();
      if (!mounted || !widget.isTop || _boundVideo != url) {
        await next.dispose();
        return;
      }
      await next.setLooping(true);
      await _applyPlaybackRole(next);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      await previous?.dispose();
    }
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdPending = false;
    _pointerStart = null;
    _movedPastCancel = false;
  }

  void _startHold(Offset local) {
    if (widget.deckDragging) return;
    _holdTimer?.cancel();
    _holdPending = true;
    _movedPastCancel = false;
    _pointerStart = local;
    _holdTimer = Timer(_holdDelay, () {
      if (!_holdPending || _movedPastCancel || !widget.isTop || !mounted)
        return;
      AppHaptics.medium();
      setState(() {
        _zoomed = true;
        _zoomPan = Offset.zero;
      });
      widget.onZoomChanged?.call(true);
    });
  }

  void _endZoom() {
    _holdTimer?.cancel();
    _holdPending = false;
    _pointerStart = null;
    _movedPastCancel = false;
    if (_zoomed && mounted) {
      setState(() {
        _zoomed = false;
        _zoomPan = Offset.zero;
      });
      widget.onZoomChanged?.call(false);
    }
  }

  bool _controlPoint(Offset local) {
    final size = context.size;
    if (size == null) return false;
    if (widget.railVisible &&
        widget.onBack != null &&
        local.dx <= 72 &&
        local.dy <= 72) {
      return true;
    }
    final topRight = widget.canUndo && widget.onUndo != null ? 92.0 : 52.0;
    if (widget.railVisible &&
        local.dx >= size.width - 52 &&
        local.dy <= topRight) {
      return true;
    }
    if (widget.railVisible &&
        local.dx >= size.width - 58 &&
        local.dy >= math.max(64.0, size.height - 420) &&
        local.dy <= size.height - 72) {
      return true;
    }
    return false;
  }

  void _pointerDown(PointerDownEvent e) {
    if (!widget.isTop ||
        widget.deckDragging ||
        _controlPoint(e.localPosition)) {
      return;
    }
    _startHold(e.localPosition);
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!widget.isTop || widget.deckDragging) return;
    final start = _pointerStart;
    if (start == null) return;
    final delta = e.localPosition - start;
    if (!_zoomed && _holdPending && delta.distance > _cancelMovePx) {
      _holdTimer?.cancel();
      _holdPending = false;
      _movedPastCancel = true;
      return;
    }
    if (_zoomed) {
      final size = context.size;
      if (size == null) return;
      final nx = (e.localPosition.dx / size.width).clamp(0.0, 1.0);
      final ny = (e.localPosition.dy / size.height).clamp(0.0, 1.0);
      final maxT = (_zoomScale - 1) / 2;
      setState(() {
        _zoomPan = Offset(
          (0.5 - nx) * 2 * maxT * size.width,
          (0.5 - ny) * 2 * maxT * size.height,
        );
      });
    }
  }

  void _pointerUp(PointerUpEvent e) {
    if (!widget.isTop) return;
    final wasZoomed = _zoomed;
    final pending = _holdPending && !_movedPastCancel;
    final start = _pointerStart;
    _holdTimer?.cancel();
    _holdPending = false;
    _pointerStart = null;
    if (wasZoomed) {
      _endZoom();
      return;
    }
    if (pending &&
        start != null &&
        (e.localPosition - start).distance < _tapMovePx) {
      _handleTap(e.localPosition);
    }
    _movedPastCancel = false;
  }

  void _handleTap(Offset local) {
    final size = context.size;
    if (size == null) return;
    if (local.dy < 56) {
      AppHaptics.light();
      widget.onSummonChrome?.call();
      return;
    }
    final media = _media;
    if (media.length > 1 && local.dx < size.width * .28) {
      AppHaptics.selection();
      _setPhoto(_photoIndex - 1);
      return;
    }
    if (media.length > 1 && local.dx > size.width * .72) {
      AppHaptics.selection();
      _setPhoto(_photoIndex + 1);
      return;
    }
    if (local.dy > size.height * .25 && local.dy < size.height * .75) {
      widget.onInsights?.call();
    }
  }

  bool get interceptsDrag => _zoomed;

  String? _posterUrl() {
    for (final url in _media) {
      if (!_isVideo(url)) return url;
    }
    return null;
  }

  Widget _coverVideo(VideoPlayerController player) {
    final source = player.value.size;
    if (source.width <= 0 || source.height <= 0) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final viewWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : viewport.width;
        final viewHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : viewport.height;
        final scale = math.max(
          viewWidth / source.width,
          viewHeight / source.height,
        );
        final renderWidth = source.width * scale;
        final renderHeight = source.height * scale;

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: renderWidth,
            maxWidth: renderWidth,
            minHeight: renderHeight,
            maxHeight: renderHeight,
            child: SizedBox(
              width: renderWidth,
              height: renderHeight,
              child: VideoPlayer(player),
            ),
          ),
        );
      },
    );
  }

  Widget _videoPoster() {
    final poster = _posterUrl();
    if (poster == null) return _fallback();
    return _cachedCoverImage(poster);
  }

  Widget _primaryMedia(String? current) {
    // Neighbor cards stay on a decoded still image so web/PWA never waits on a
    // platform video view while the user is mid vertical swipe.
    if (widget.prepareMedia && !widget.isTop) {
      final still = _heroImageUrl();
      return still == null ? _fallback() : _cachedCoverImage(still);
    }
    if (current == null) return _fallback();
    if (_isVideo(current)) {
      final player = _video;
      final ready = player != null && player.value.isInitialized;
      return Stack(
        fit: StackFit.expand,
        children: [
          _videoPoster(),
          if (ready)
            IgnorePointer(
              ignoring: !_zoomed,
              child: RepaintBoundary(child: _coverVideo(player)),
            ),
        ],
      );
    }
    return _cachedCoverImage(current);
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final current = media.isEmpty ? null : media[_photoIndex % media.length];
    final soundOn = ref.watch(deckSoundOnProvider);
    final radiusKm = ref.watch(discoveryLocationProvider).radiusKm;
    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      if (!widget.isTop) return;
      final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
      final wantSound = on && (unlocked || !kIsWeb);
      _video?.setVolume(wantSound ? 1 : 0);
    });
    if (widget.isTop &&
        current != null &&
        _isVideo(current) &&
        _video == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_syncVideo());
      });
    } else if (widget.isTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final handoff = SwipeDeckMediaHandoff.take();
        if (handoff != null) unawaited(handoff.controller?.dispose());
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerUp,
        onPointerCancel: (_) => _endZoom(),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: _zoomed
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                transformAlignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(_zoomPan.dx, _zoomPan.dy, 0, 1)
                  ..scaleByDouble(
                    _zoomed ? _zoomScale : 1,
                    _zoomed ? _zoomScale : 1,
                    1,
                    1,
                  ),
                child: _primaryMedia(current),
              ),
              if (!_zoomed)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x66000000),
                        Color(0xD9000000),
                      ],
                      stops: [.45, .72, 1],
                    ),
                  ),
                ),
              if (!_zoomed && media.length > 1)
                Positioned(
                  top: 14,
                  left: 56,
                  right: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < media.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        AnimatedContainer(
                          duration: widget.deckDragging
                              ? Duration.zero
                              : const Duration(milliseconds: 90),
                          width: i == _photoIndex ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _photoIndex
                                ? Colors.white
                                : Colors.white.withAlpha(110),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (!_zoomed)
                Positioned(
                  top: 66,
                  left: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.listing.hasVerifiedDocuments)
                        _GlassLabel(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: Color(0xFF1687FF),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'VERIFIED',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final match = listingMatchPercentage(
                            widget.listing,
                            ref.watch(swipeFilterProvider),
                          );
                          if (match <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: EdgeInsets.only(
                              top: widget.listing.hasVerifiedDocuments ? 8 : 0,
                            ),
                            child: SwipeMatchMeter(percentage: match),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              if (!_zoomed && widget.onBack != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _HudVisibility(
                    visible: widget.railVisible,
                    hiddenOffset: const Offset(-0.14, 0),
                    child: _GlassCircle(
                      size: 48,
                      iconSize: 28,
                      icon: Icons.chevron_left_rounded,
                      onTap: widget.onBack!,
                    ),
                  ),
                ),
              if (!_zoomed)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _HudVisibility(
                    visible: widget.railVisible,
                    hiddenOffset: const Offset(0.14, 0),
                    child: Column(
                      children: [
                        if (widget.canUndo && widget.onUndo != null) ...[
                          _GlassCircle(
                            size: 36,
                            iconSize: 18,
                            icon: Icons.undo_rounded,
                            onTap: widget.onUndo!,
                          ),
                          const SizedBox(height: 6),
                        ],
                        _MuteButton(
                          soundOn: soundOn,
                          onTap: () {
                            AppHaptics.selection();
                            unlockDeckMedia();
                            ref.read(deckSoundOnProvider.notifier).toggle();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_zoomed)
                Positioned(
                  right: 4,
                  bottom: 88,
                  child: _HudVisibility(
                    visible: widget.railVisible,
                    hiddenOffset: const Offset(0.18, 0),
                    child: Column(
                      children: [
                        _GlassLabel(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                              Text(
                                '${radiusKm}KM',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        _GlassCircle(
                          size: 40,
                          iconSize: 17,
                          icon: Icons.map_rounded,
                          onTap: () {
                            AppHaptics.light();
                            widget.onOpenMap?.call();
                          },
                        ),
                        const SizedBox(height: 6),
                        _ActionRail(
                          onAi: widget.onOpenAi,
                          onShare: widget.onShare,
                          onMessage: widget.onMessage,
                          onInsights: widget.onInsights,
                          onReport: widget.onReport,
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_zoomed)
                Positioned(
                  left: 14,
                  right: 50,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFF3040),
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.listing.likes ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: const Color(0x8C141418),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.listing.formattedPrice,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.listing.title ?? 'Listing',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.likeOpacity > .02)
                Positioned(
                  top: 56,
                  left: 22,
                  child: Opacity(
                    opacity: widget.likeOpacity.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: -10 * math.pi / 180,
                      child: Transform.scale(
                        scale: .82 + widget.likeOpacity * .28,
                        alignment: Alignment.topLeft,
                        child: _SwipeFeedbackLabel(
                          label: 'LIKE',
                          color: const Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.nopeOpacity > .02)
                Positioned(
                  top: 56,
                  right: 22,
                  child: Opacity(
                    opacity: widget.nopeOpacity.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: 10 * math.pi / 180,
                      child: Transform.scale(
                        scale: .82 + widget.nopeOpacity * .28,
                        alignment: Alignment.topRight,
                        child: _SwipeFeedbackLabel(
                          label: 'NOPE',
                          color: const Color(0xFFFB7185),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => const ColoredBox(color: Color(0xFF111827));
}

class _SwipeFeedbackLabel extends StatelessWidget {
  const _SwipeFeedbackLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
        shadows: [Shadow(color: color.withAlpha(130), blurRadius: 12)],
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    this.onAi,
    this.onShare,
    this.onMessage,
    this.onInsights,
    this.onReport,
  });
  final VoidCallback? onAi;
  final VoidCallback? onShare;
  final VoidCallback? onMessage;
  final VoidCallback? onInsights;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailButton(
          onTap: onAi,
          child: Text(
            'AI',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
            ),
          ),
        ),
        _RailButton(
          onTap: onShare,
          child: const Icon(
            Icons.share_rounded,
            size: 17,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
        _RailButton(
          onTap: onMessage,
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 17,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
        _RailButton(
          onTap: onInsights,
          child: const Icon(
            Icons.bar_chart_rounded,
            size: 17,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
        _RailButton(
          onTap: onReport,
          child: const Icon(
            Icons.flag_outlined,
            size: 17,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.selection();
        onTap?.call();
      },
      child: SizedBox(width: 34, height: 34, child: Center(child: child)),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.iconSize = 18,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
      ),
    );
  }
}

class _GlassLabel extends StatelessWidget {
  const _GlassLabel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(64),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.soundOn, required this.onTap});
  final bool soundOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: BreathingWidget(
            child: Icon(
              soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: Colors.white,
              size: 16,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudVisibility extends StatelessWidget {
  const _HudVisibility({
    required this.visible,
    required this.child,
    this.hiddenOffset = Offset.zero,
  });

  final bool visible;
  final Widget child;
  final Offset hiddenOffset;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 300);
    const settle = Cubic(0.16, 1, 0.3, 1);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : hiddenOffset,
          duration: duration,
          curve: settle,
          child: AnimatedScale(
            scale: visible ? 1 : 0.92,
            duration: duration,
            curve: settle,
            child: child,
          ),
        ),
      ),
    );
  }
}
