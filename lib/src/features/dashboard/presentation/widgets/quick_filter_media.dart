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

/// Global cap so the bento grid cannot spawn N simultaneous HTML5 videos.
class _VideoBudget {
  /// Web: keep stills on regular tiles — EventsTeaser owns the one video slot.
  static int get maxActive => kIsWeb ? 0 : 2;
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

/// Cap `QuickFilterImage` — unique shuffled pool + staggered round-robin rotate.
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

  /// Index in the round-robin (0 = first card to advance).
  final int rotateSlot;

  /// Total participating quick-filter slots on the dashboard.
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

  List<String> get _sources {
    if (_pool.isEmpty) return const <String>[];
    if (widget.enableVideo) return _pool;
    final stills = _pool
        .where((u) => !isQuickFilterVideoUrl(u))
        .toList(growable: false);
    return stills.isEmpty ? _pool : stills;
  }

  @override
  void initState() {
    super.initState();
    _reshuffle(widget.sources);
  }

  @override
  void didUpdateWidget(covariant QuickFilterMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.sources, widget.sources) ||
        oldWidget.enableVideo != widget.enableVideo) {
      _reshuffle(widget.sources);
      _syncVideo();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _reshuffle(List<String> sources) {
    _pool = List<String>.from(sources);
    if (_pool.length > 1) {
      _pool.shuffle(
        math.Random(
          DateTime.now().microsecondsSinceEpoch ^ widget.rotateSlot * 7919,
        ),
      );
    }
    _index = 0;
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
      final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
      final wantSound = soundOn && (unlocked || !kIsWeb);
      await next.setLooping(true);
      await next.setVolume(wantSound ? 1 : 0);
      await next.play();
      if (wantSound) await next.setVolume(1);
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

    // Round-robin: only this card advances when the global tick lands on its slot.
    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {
      final slots = widget.slotCount.clamp(1, 64);
      if (next % slots == widget.rotateSlot % slots) {
        _advance(1);
      }
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_dragDx.abs() > 20) {
          AppHaptics.selection();
          _advance(_dragDx < 0 ? 1 : -1);
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
                  AppHaptics.selection();
                  unlockDeckMedia();
                  ref.read(deckSoundOnProvider.notifier).toggle();
                  _video?.setVolume(ref.read(deckSoundOnProvider) ? 1 : 0);
                  if (ref.read(deckSoundOnProvider)) {
                    _video?.play();
                  }
                },
                child: BreathingWidget(
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    // No white ring — icon + soft dark chip only.
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
            ),
        ],
      ),
    );
  }
}
