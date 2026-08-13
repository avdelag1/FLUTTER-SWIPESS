import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

/// Cap `EventsVideoQuickFilter` — segments + shared mute + advance on end.
class EventsTeaserCard extends ConsumerStatefulWidget {
  const EventsTeaserCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  ConsumerState<EventsTeaserCard> createState() => _EventsTeaserCardState();
}

class _EventsTeaserCardState extends ConsumerState<EventsTeaserCard> {
  VideoPlayerController? _player;
  int _index = 0;
  String? _boundUrl;
  double _dragDx = 0;

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  void _onTick() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    final videos = ref.read(videoEventsProvider);
    if (videos.length <= 1) return;
    if (player.value.position >= player.value.duration &&
        player.value.duration > Duration.zero) {
      _index = (_index + 1) % videos.length;
      _bind(videos);
    }
  }

  Future<void> _bind(List<Event> videos) async {
    if (videos.isEmpty) return;
    if (_index >= videos.length) _index = 0;
    final url = videos[_index].videoUrl;
    if (url == null || url == _boundUrl) return;
    _boundUrl = url;
    final previous = _player;
    previous?.removeListener(_onTick);
    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = next;
    try {
      await next.initialize();
      await next.setLooping(videos.length == 1);
      final soundOn = ref.read(deckSoundOnProvider);
      await next.setVolume(soundOn ? 1 : 0);
      await next.play();
      next.addListener(_onTick);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      await previous?.dispose();
    }
  }

  void _advance(List<Event> videos, int delta) {
    if (videos.isEmpty) return;
    _index = (_index + delta) % videos.length;
    if (_index < 0) _index += videos.length;
    _boundUrl = null;
    _bind(videos);
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(videoEventsProvider);
    final soundOn = ref.watch(deckSoundOnProvider);
    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      _player?.setVolume(on ? 1 : 0);
    });
    ref.listen<List<Event>>(videoEventsProvider, (_, next) {
      _bind(next);
    });
    if (videos.isNotEmpty && _player == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bind(videos);
      });
    }
    final current = videos.isEmpty ? null : videos[_index % videos.length];
    final ready = _player != null && _player!.value.isInitialized;
    final segmentCount = videos.isEmpty ? 1 : videos.length.clamp(1, 8);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap?.call();
      },
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_dragDx.abs() > 20 && videos.length > 1) {
          HapticFeedback.selectionClick();
          _advance(videos, _dragDx < 0 ? 1 : -1);
        }
        _dragDx = 0;
      },
      child: ClipRRect(
        borderRadius: AppTheme.qfNeoFrameRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _player!.value.size.width,
                  height: _player!.value.size.height,
                  child: VideoPlayer(_player!),
                ),
              )
            else if (current?.imageUrl != null)
              Image.network(current!.imageUrl!, fit: BoxFit.cover)
            else
              Image.asset(AppAssets.filterEvents, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xCC000000)],
                ),
              ),
            ),
            if (!ready)
              const Center(
                child: Icon(Icons.celebration_outlined,
                    color: Color(0xB3FFFFFF), size: 40),
              ),
            Positioned(
              top: 10,
              left: 10,
              right: 44,
              child: Row(
                children: [
                  for (var i = 0; i < segmentCount; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: i == (_index % segmentCount) ? 14 : 6,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i == (_index % segmentCount)
                            ? Colors.white
                            : Colors.white.withAlpha(110),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                    border: Border.all(color: Colors.transparent),
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
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EVENTS LIVE',
                    style: AppTheme.displayItalic.copyWith(
                      fontSize: 14,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    current?.title ?? 'Local Event',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xCCFFFFFF),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
