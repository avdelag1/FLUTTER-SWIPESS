import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
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

/// Global cap so the bento grid cannot spawn N simultaneous HTML5 videos
/// (the main FPS killer on Flutter web).
class _VideoBudget {
  static const maxActive = 2;
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

/// Cap `QuickFilterImage` — multi-media carousel with story segments + mute.
///
/// Rotates every ~6.5s (user Cap-parity ask). Supports network photos, asset
/// photos, and looping videos with a shared deck mute control.
class QuickFilterMedia extends ConsumerStatefulWidget {
  const QuickFilterMedia({
    super.key,
    required this.sources,
    this.animationDelay = Duration.zero,
    this.showMute = true,
    this.rotateEvery = const Duration(milliseconds: 6500),
    this.enableVideo = true,
  });

  final List<String> sources;
  final Duration animationDelay;
  final bool showMute;
  final Duration rotateEvery;

  /// When false, video URLs are skipped (still photos only) — use for
  /// off-screen / lower bento tiles to keep the dashboard snappy.
  final bool enableVideo;

  @override
  ConsumerState<QuickFilterMedia> createState() => _QuickFilterMediaState();
}

class _QuickFilterMediaState extends ConsumerState<QuickFilterMedia> {
  int _index = 0;
  Timer? _timer;
  VideoPlayerController? _video;
  String? _boundVideoUrl;
  double _dragDx = 0;
  bool _holdsBudgetSlot = false;

  List<String> get _sources {
    if (widget.sources.isEmpty) return const <String>[];
    if (widget.enableVideo) return widget.sources;
    final stills = widget.sources
        .where((u) => !isQuickFilterVideoUrl(u))
        .toList(growable: false);
    return stills.isEmpty ? widget.sources : stills;
  }

  @override
  void initState() {
    super.initState();
    _scheduleRotate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVideo());
  }

  @override
  void didUpdateWidget(covariant QuickFilterMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sources != widget.sources ||
        oldWidget.enableVideo != widget.enableVideo) {
      _index = 0;
      _scheduleRotate();
      _syncVideo();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposeVideo();
    super.dispose();
  }

  void _disposeVideo() {
    if (_holdsBudgetSlot) {
      _VideoBudget.release();
      _holdsBudgetSlot = false;
    }
    _video?.dispose();
    _video = null;
    _boundVideoUrl = null;
  }

  void _scheduleRotate() {
    _timer?.cancel();
    if (_sources.length <= 1) return;
    final first = widget.rotateEvery + widget.animationDelay;
    _timer = Timer(first, () {
      _advance(1);
      _timer = Timer.periodic(widget.rotateEvery, (_) => _advance(1));
    });
  }

  void _advance(int delta) {
    if (_sources.isEmpty || !mounted) return;
    setState(() {
      _index = (_index + delta) % _sources.length;
      if (_index < 0) _index += _sources.length;
    });
    _syncVideo();
  }

  Future<void> _syncVideo() async {
    if (_sources.isEmpty) return;
    final url = _sources[_index % _sources.length];
    if (!widget.enableVideo || !isQuickFilterVideoUrl(url)) {
      _disposeVideo();
      if (mounted) setState(() {});
      return;
    }
    if (url == _boundVideoUrl && _video != null) {
      final soundOn = ref.read(deckSoundOnProvider);
      await _video!.setVolume(soundOn ? 1 : 0);
      return;
    }

    // Skip decode when the concurrent video budget is exhausted (common on
    // Flutter web where each VideoPlayer is an expensive HTML5 element).
    if (!_holdsBudgetSlot && !_VideoBudget.tryAcquire()) {
      _disposeVideo();
      if (mounted) setState(() {});
      return;
    }
    _holdsBudgetSlot = true;

    _boundVideoUrl = url;
    final previous = _video;
    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = next;
    try {
      await next.initialize();
      if (!mounted || _boundVideoUrl != url) {
        await next.dispose();
        if (identical(_video, next)) {
          _video = null;
          _boundVideoUrl = null;
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
      await previous?.dispose();
    }
  }

  void _onSoundChanged(bool soundOn) {
    _video?.setVolume(soundOn ? 1 : 0);
  }

  Widget _buildMedia(String url) {
    if (isQuickFilterVideoUrl(url)) {
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
      // Prefer a cheap placeholder over blocking on video init.
      return const ColoredBox(color: Color(0xFF16161C));
    }
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF16161C)),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = MediaQuery.sizeOf(context).width;
    // Bento tiles are ~half width; decode closer to on-screen pixels.
    final cacheW = (logicalW * dpr * 0.55).round().clamp(320, 900);
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheW,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF16161C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources;
    if (sources.isEmpty) {
      return const ColoredBox(color: Color(0xFF16161C));
    }
    final current = sources[_index % sources.length];
    final soundOn = ref.watch(deckSoundOnProvider);
    ref.listen<bool>(deckSoundOnProvider, (_, next) => _onSoundChanged(next));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_dragDx.abs() > 20) {
          HapticFeedback.selectionClick();
          _advance(_dragDx < 0 ? 1 : -1);
          _scheduleRotate();
        }
        _dragDx = 0;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: kIsWeb ? 220 : 420),
            child: KeyedSubtree(
              key: ValueKey(current),
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
                      duration: const Duration(milliseconds: 220),
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
          if (widget.showMute)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(deckSoundOnProvider.notifier).toggle();
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  child: Icon(
                    soundOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
