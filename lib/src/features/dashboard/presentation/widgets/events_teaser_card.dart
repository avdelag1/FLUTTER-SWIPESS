import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

/// Dashboard bento teaser — loops event videos like Capacitor `EventsVideoQuickFilter`.
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
      await next.setVolume(0);
      await next.play();
      next.addListener(_onTick);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      await previous?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(videoEventsProvider);
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

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap?.call();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
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
                child: Icon(Icons.celebration_outlined, color: Color(0xB3FFFFFF), size: 40),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EVENTS',
                    style: AppTheme.displayItalic.copyWith(
                      fontSize: 18,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    current?.title ?? 'Discover Local',
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
