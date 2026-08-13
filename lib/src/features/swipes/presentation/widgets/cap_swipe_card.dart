import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_gesture_hints.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

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

  static const _holdDelay = Duration(milliseconds: 120);
  static const _zoomScale = 3.2;
  static const _cancelMovePx = 25.0;

  List<String> get _media {
    final images = widget.listing.images;
    final video = widget.listing.videoUrl;
    if (images.isEmpty && (video == null || video.isEmpty)) {
      return const [];
    }
    final out = <String>[...images];
    if (video != null &&
        video.isNotEmpty &&
        !out.contains(video)) {
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
      _syncVideo();
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
    setState(() => _photoIndex = index % media.length);
    widget.onPhotoIndexChanged?.call(_photoIndex);
    _syncVideo();
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
      _disposeVideo();
      if (mounted) setState(() {});
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
      HapticFeedback.mediumImpact();
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
    if (_zoomed) {
      setState(() {
        _zoomed = false;
        _zoomPan = Offset.zero;
      });
      widget.onZoomChanged?.call(false);
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.isTop) return;
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
      if (dist < 12) {
        _handleTap(e.localPosition);
      }
    }
  }

  void _handleTap(Offset local) {
    final box = context.size;
    if (box == null) return;
    final w = box.width;
    final h = box.height;
    final x = local.dx;
    final y = local.dy;

    // Top strip summons chrome (Cap ChromeSummonZones).
    if (y < 56) {
      widget.onSummonChrome?.call();
      return;
    }

    final media = _media;
    if (media.length > 1 && x < w * 0.28) {
      HapticFeedback.selectionClick();
      _setPhoto((_photoIndex - 1 + media.length) % media.length);
      return;
    }
    if (media.length > 1 && x > w * 0.72) {
      HapticFeedback.selectionClick();
      _setPhoto((_photoIndex + 1) % media.length);
      return;
    }

    // Center tap → Insights
    if (y > h * 0.25 && y < h * 0.75) {
      HapticFeedback.lightImpact();
      widget.onInsights?.call();
    }
  }

  bool get interceptsDrag => _zoomed || _holdPending;

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
        if (mounted && widget.isTop) _syncVideo();
      });
    }

    final likeScale = 0.6 + widget.likeOpacity * 0.6;
    final nopeScale = 0.6 + widget.nopeOpacity * 0.6;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Listener(
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
                    : const Duration(milliseconds: 220),
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
                        : Image.network(
                            current,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            // Decode near display size — full Unsplash
                            // bitmaps crush Flutter web FPS.
                            cacheWidth:
                                (MediaQuery.sizeOf(context).width * 2)
                                    .round()
                                    .clamp(480, 1600),
                            filterQuality: FilterQuality.medium,
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

              if (widget.isTop)
                SwipeGestureHints(
                  hidden: _zoomed ||
                      widget.likeOpacity > 0.08 ||
                      widget.nopeOpacity > 0.08,
                ),

              // Photo segments
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
                          duration: const Duration(milliseconds: 180),
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

              // Top-left back
              if (!_zoomed && widget.onBack != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _GlassCircle(
                    icon: Icons.chevron_left_rounded,
                    onTap: widget.onBack!,
                  ),
                ),

              // Top-right undo + mute
              if (!_zoomed)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      if (widget.canUndo && widget.onUndo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _GlassCircle(
                            icon: Icons.replay_rounded,
                            onTap: widget.onUndo!,
                          ),
                        ),
                      _GlassCircle(
                        icon: soundOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(deckSoundOnProvider.notifier).toggle();
                        },
                      ),
                    ],
                  ),
                ),

              // Mid-right KM + map (outside rail column)
              if (!_zoomed && widget.isTop && widget.railVisible)
                Positioned(
                  right: 10,
                  top: MediaQuery.sizeOf(context).height * 0.22,
                  child: Column(
                    children: [
                      _GlassPill(
                        child: Column(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white, size: 16),
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
                      const SizedBox(height: 8),
                      _GlassCircle(
                        icon: Icons.map_rounded,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onOpenMap?.call();
                        },
                      ),
                    ],
                  ),
                ),

              // Right action rail
              if (!_zoomed && widget.isTop && widget.railVisible)
                Positioned(
                  right: 10,
                  bottom: 120,
                  child: _ActionRail(
                    onAi: widget.onOpenAi,
                    onShare: widget.onShare,
                    onMessage: widget.onMessage,
                    onInsights: widget.onInsights,
                    onReport: widget.onReport,
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
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFD43B), size: 14),
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
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(150),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
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
                                  color: Colors.white54,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 4),
        color: color.withAlpha(45),
        boxShadow: [
          BoxShadow(color: color.withAlpha(80), blurRadius: 18),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(100),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
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
                fontSize: 11,
              ),
            ),
          ),
          _RailBtn(
            onTap: onShare,
            child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
          ),
          _RailBtn(
            onTap: onMessage,
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white, size: 18),
          ),
          _RailBtn(
            onTap: onInsights,
            child: const Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: 18),
          ),
          _RailBtn(
            onTap: onReport,
            child: const Icon(Icons.flag_outlined, color: Colors.white, size: 18),
          ),
        ],
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
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(width: 40, height: 40, child: Center(child: child)),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(110),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
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
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: child,
    );
  }
}
