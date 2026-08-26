import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_match_score.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_match_meter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Cap `SimpleSwipeCard` visual + hold-zoom + photo segments + right rail.
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
  });

  final Listing listing;
  final bool isTop;
  final double likeOpacity;
  final double nopeOpacity;
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

  // A normal tap should always win. Zoom only begins after a clearly deliberate
  // press, while tiny movement cancels the pending hold quickly so card swipes
  // remain immediate.
  static const _holdDelay = Duration(milliseconds: 360);
  static const _zoomScale = 3.2;
  static const _cancelMovePx = 10.0;
  static const _tapMovePx = 12.0;

  List<String> get _media {
    final images = widget.listing.images;
    final video = widget.listing.videoUrl;
    if (images.isEmpty && (video == null || video.isEmpty)) {
      return const [];
    }
    final out = <String>[...images];
    if (video != null && video.isNotEmpty && !out.contains(video)) {
      out.add(video);
    }
    return out;
  }

  bool _isVideo(String url) {
    final l = url.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('/videos/');
  }

  @override
  void didUpdateWidget(covariant CapSwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listing.id != widget.listing.id) {
      _photoIndex = 0;
      _endZoom();
    }
    // Back-stack cards must not decode video — only the top card plays.
    if (!widget.isTop) {
      _disposeVideo();
      return;
    }
    if (oldWidget.listing.id != widget.listing.id || !oldWidget.isTop) {
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
    _video?.dispose();
    _video = null;
    _boundVideo = null;
  }

  void _setPhoto(int index) {
    final media = _media;
    if (media.isEmpty) return;
    final normalized = ((index % media.length) + media.length) % media.length;
    if (normalized == _photoIndex) return;

    // The UI index and the already-prefetched image swap happen in the same
    // frame. Video setup can continue asynchronously without delaying taps.
    setState(() => _photoIndex = normalized);
    widget.onPhotoIndexChanged?.call(normalized);
    unawaited(_syncVideo());
  }

  Future<void> _syncVideo() async {
    // Non-top cards in the stack only show stills / placeholders.
    if (!widget.isTop) {
      _disposeVideo();
      return;
    }
    final media = _media;
    if (media.isEmpty) return;
    final url = media[_photoIndex % media.length];
    if (!_isVideo(url)) {
      // An image is already visible because _setPhoto rebuilt synchronously;
      // avoid a redundant second rebuild when leaving video media.
      if (_video != null || _boundVideo != null) _disposeVideo();
      return;
    }
    if (url == _boundVideo && _video != null) return;
    _boundVideo = url;
    final prev = _video;
    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = next;
    try {
      await next.initialize();
      if (!mounted || !widget.isTop || _boundVideo != url) {
        await next.dispose();
        if (identical(_video, next)) {
          _video = null;
          _boundVideo = null;
        }
        return;
      }
      final soundOn = ref.read(deckSoundOnProvider);
      await next.setLooping(true);
      await next.setVolume(soundOn ? 1 : 0);
      await next.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      await prev?.dispose();
    }
  }

  void _startHold(Offset local) {
    _holdTimer?.cancel();
    _holdPending = true;
    _movedPastCancel = false;
    _pointerStart = local;
    _holdTimer = Timer(_holdDelay, () {
      if (!_holdPending || _movedPastCancel || !widget.isTop) return;
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
    if (_zoomed) {
      setState(() {
        _zoomed = false;
        _zoomPan = Offset.zero;
      });
      widget.onZoomChanged?.call(false);
    }
  }

  bool _isInteractiveControlPoint(Offset local) {
    final box = context.size;
    if (box == null) return false;
    final w = box.width;
    final h = box.height;
    final x = local.dx;
    final y = local.dy;

    // Raw pointer listening gives media taps maximum speed, but these visible
    // controls must win the hit. Otherwise pressing Share/Message/Back/Mute can
    // also be mistaken for a photo-edge or chrome-summon tap.
    if (widget.onBack != null && x <= 72 && y <= 72) return true;

    final topRightHeight = widget.canUndo && widget.onUndo != null ? 116.0 : 62.0;
    if (x >= w - 68 && y <= topRightHeight) return true;

    if (widget.railVisible &&
        x >= w - 86 &&
        y >= math.max(64.0, h - 520) &&
        y <= h - 96) {
      return true;
    }

    return false;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.isTop || _isInteractiveControlPoint(e.localPosition)) return;
    _startHold(e.localPosition);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.isTop) return;
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
      final box = context.size;
      if (box == null) return;
      final nx = (e.localPosition.dx / box.width).clamp(0.0, 1.0);
      final ny = (e.localPosition.dy / box.height).clamp(0.0, 1.0);
      final maxT = ((_zoomScale - 1) / 2);
      setState(() {
        _zoomPan = Offset(
          (0.5 - nx) * 2 * maxT * box.width,
          (0.5 - ny) * 2 * maxT * box.height,
        );
      });
    }
  }

  void _onPointerUp(PointerUpEvent e) {
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

    if (pending && start != null) {
      final dist = (e.localPosition - start).distance;
      if (dist < _tapMovePx) {
        _handleTap(e.localPosition);
      }
    }
    _movedPastCancel = false;
  }

  void _handleTap(Offset local) {
    final box = context.size;
    if (box == null) return;
    final w = box.width;
    final h = box.height;
    final x = local.dx;
    final y = local.dy;

    // Top strip summons all shared chrome: header, bottom dock and the card rail.
    if (y < 56) {
      AppHaptics.light();
      widget.onSummonChrome?.call();
      return;
    }

    // Edge taps are intentionally checked before the center action so they can
    // flip photos at full tap speed without waiting on any zoom recognizer.
    final media = _media;
    if (media.length > 1 && x < w * 0.28) {
      AppHaptics.selection();
      _setPhoto(_photoIndex - 1);
      return;
    }
    if (media.length > 1 && x > w * 0.72) {
      AppHaptics.selection();
      _setPhoto(_photoIndex + 1);
      return;
    }

    // Center tap → Insights.
    if (y > h * 0.25 && y < h * 0.75) {
      AppHaptics.light();
      widget.onInsights?.call();
    }
  }

  // A pending hold must never steal the parent card's horizontal drag. Only an
  // already-activated deliberate zoom locks the swipe gesture.
  bool get interceptsDrag => _zoomed;

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final hasMedia = media.isNotEmpty;
    final current = hasMedia ? media[_photoIndex % media.length] : null;
    final soundOn = ref.watch(deckSoundOnProvider);
    final radiusKm = ref.watch(discoveryLocationProvider).radiusKm;
    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      _video?.setVolume(on ? 1 : 0);
    });
    if (widget.isTop &&
        hasMedia &&
        _video == null &&
        current != null &&
        _isVideo(current)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isTop) unawaited(_syncVideo());
      });
    }

    final likeScale = 0.6 + widget.likeOpacity * 0.6;
    final nopeScale = 0.6 + widget.nopeOpacity * 0.6;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: (_) => _endZoom(),
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media
              AnimatedContainer(
                duration: _zoomed
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                transformAlignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(_zoomPan.dx, _zoomPan.dy, 0, 1)
                  ..scaleByDouble(
                    _zoomed ? _zoomScale : 1,
                    _zoomed ? _zoomScale : 1,
                    1,
                    1,
                  ),
                child: current == null
                    ? _fallback()
                    : _isVideo(current)
                    ? _buildVideo()
                    : CachedNetworkImage(
  imageUrl: current,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.12),
                        width: double.infinity,
                        height: double.infinity,
                        // Decode near display size — full remote bitmaps crush
                        // Flutter FPS. SwipeableCardStack precaches using this
                        // exact resized key so edge taps display immediately.
                        cacheWidth: (MediaQuery.sizeOf(context).width * 2)
                            .round()
                            .clamp(480, 1600),
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => _fallback(),
                      ),
              ),

              if (!_zoomed)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.45, 0.7, 1],
                      colors: [
                        Colors.transparent,
                        Color(0x66000000),
                        Color(0xCC000000),
                      ],
                    ),
                  ),
                ),

              if (!_zoomed && widget.listing.reappearedReason != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.listing.reappearedReason == 'price_dropped'
                          ? const Color(0xFF34D399).withAlpha(200)
                          : Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.listing.reappearedReason == 'price_dropped'
                              ? Icons.arrow_downward_rounded
                              : Icons.history_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.listing.reappearedReason == 'price_dropped'
                              ? 'PRICE DROPPED'
                              : 'REAPPEARED',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Photo index feedback is intentionally fast so it lands in the
              // same visual beat as the already-cached image swap.
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
                          duration: const Duration(milliseconds: 90),
                          curve: Curves.easeOutCubic,
                          width: i == _photoIndex ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _photoIndex
                                ? Colors.white
                                : Colors.white.withAlpha(110),
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: i == _photoIndex
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withAlpha(120),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Cap Verified pill + SwipeMatchMeter
              if (!_zoomed)
                Positioned(
                  top: 66,
                  left: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.listing.hasVerifiedDocuments)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(90),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withAlpha(70),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6)
                                        .withAlpha(100),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFA78BFA),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'VERIFIED',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

              // Top-left back
              if (!_zoomed && widget.onBack != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _GlassCircle(
                    size: 48,
                    iconSize: 28,
                    icon: Icons.chevron_left_rounded,
                    onTap: widget.onBack!,
                  ),
                ),

              // Top-right return (one-shot undo) + mute
              if (!_zoomed)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      if (widget.canUndo && widget.onUndo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GlassCircle(
                            size: 44,
                            iconSize: 22,
                            icon: Icons.undo_rounded,
                            onTap: widget.onUndo!,
                          ),
                        ),
                      _MuteIconButton(
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

              // Cap right column: KM (top rail) → Map 58px → glass action rail.
              // Map sits just above the bottom-right rail (not mid-height).
              if (!_zoomed && widget.isTop && widget.railVisible)
                Positioned(
                  right: 12,
                  bottom: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GlassPill(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            Text(
                              '${radiusKm}KM',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _GlassCircle(
                        size: 58,
                        iconSize: 22,
                        icon: Icons.map_rounded,
                        onTap: () {
                          AppHaptics.light();
                          widget.onOpenMap?.call();
                        },
                      ),
                      const SizedBox(height: 10),
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

              // Rating + info
              if (!_zoomed)
                Positioned(
                  left: 14,
                  right: 72,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFD43B),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '5.0',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '  (${widget.listing.likes ?? 0})',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: const Color(0x8C141418),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(140),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.listing.formattedPrice,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.listing.title ?? 'Listing',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (widget.listing.propertyType != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.listing.propertyType!,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // LIKE banner — zooms from top-left
              if (widget.likeOpacity > 0.02)
                Positioned(
                  top: 48,
                  left: 24,
                  child: Opacity(
                    opacity: widget.likeOpacity.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: -12 * math.pi / 180,
                      child: Transform.scale(
                        scale: likeScale,
                        alignment: Alignment.topLeft,
                        child: _Stamp(
                          text: 'LIKE',
                          color: const Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ),
                ),

              // NOPE banner — zooms from top-right
              if (widget.nopeOpacity > 0.02)
                Positioned(
                  top: 48,
                  right: 24,
                  child: Opacity(
                    opacity: widget.nopeOpacity.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: 12 * math.pi / 180,
                      child: Transform.scale(
                        scale: nopeScale,
                        alignment: Alignment.topRight,
                        child: _Stamp(
                          text: 'NOPE',
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

  Widget _buildVideo() {
    final player = _video;
    if (player == null || !player.value.isInitialized) {
      return _fallback();
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: player.value.size.width,
        height: player.value.size.height,
        child: VideoPlayer(player),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isLike = text == 'LIKE';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLike ? 28 : 36,
        vertical: isLike ? 12 : 20,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isLike ? 24 : 999),
        border: isLike ? Border.all(color: color, width: 4) : null,
        color: Colors.black.withAlpha(isLike ? 50 : 0),
        boxShadow: [BoxShadow(color: color.withAlpha(100), blurRadius: 24)],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: isLike ? 48 : 44,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
          shadows: [Shadow(color: color.withAlpha(180), blurRadius: 20)],
        ),
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
    // Cap: rounded-3xl glass column, 46×46 tap targets, frameless icons.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(77),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(77)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 48,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailBtn(
                onTap: onAi,
                child: Text(
                  'AI',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              _RailBtn(
                onTap: onShare,
                child: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              _RailBtn(
                onTap: onMessage,
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              _RailBtn(
                onTap: onInsights,
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              _RailBtn(
                onTap: onReport,
                child: const Icon(
                  Icons.flag_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailBtn extends StatelessWidget {
  const _RailBtn({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(width: 46, height: 46, child: Center(child: child)),
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
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(77),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(77)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(128),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}

/// Deck mute — soft dark chip, no white ring (Cap volume icon).
class _MuteIconButton extends StatelessWidget {
  const _MuteIconButton({required this.soundOn, required this.onTap});

  final bool soundOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: BreathingWidget(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(110),
                shape: BoxShape.circle,
              ),
              child: Icon(
                soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(77),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(77)),
      ),
      child: child,
    );
  }
}
