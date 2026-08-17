import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/event_preview_handoff.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/event_mute_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class EventsTeaserCard extends ConsumerStatefulWidget {
  const EventsTeaserCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  ConsumerState<EventsTeaserCard> createState() => _EventsTeaserCardState();
}

class _EventsTeaserCardState extends ConsumerState<EventsTeaserCard> {
  VideoPlayerController? _player;
  VideoPlayerController? _music;
  int _index = 0;
  String? _boundUrl;
  String? _musicUrl;
  double _dragDx = 0;
  bool _binding = false;
  bool _advancing = false;
  bool _leavingForEvents = false;
  bool _routeActive = true;
  double _visibleFraction = 0;
  ScrollPosition? _scrollPosition;
  bool _visibilityCheckScheduled = false;

  static const _clarityMatrix = <double>[
    1.12, 0, 0, 0, 3,
    0, 1.12, 0, 0, 3,
    0, 0, 1.12, 0, 3,
    0, 0, 0, 1, 0,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleVisibilityCheck());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRouteActive = TickerMode.of(context);
    if (_routeActive != nextRouteActive) {
      _routeActive = nextRouteActive;
      if (!_routeActive) {
        _visibleFraction = 0;
        _pauseInvisible();
      } else {
        _leavingForEvents = false;
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
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _player?.removeListener(_onTick);
    _player?.dispose();
    _music?.dispose();
    super.dispose();
  }

  List<Event> _videos(List<Event> fromApi) => fromApi;

  Event? _currentOf(List<Event> videos) {
    if (videos.isEmpty) return null;
    return videos[_index % videos.length];
  }

  bool get _wantSound {
    final notifier = ref.read(deckSoundOnProvider.notifier);
    return ref.read(deckSoundOnProvider) && (notifier.mediaUnlocked || !kIsWeb);
  }

  void _scheduleVisibilityCheck() {
    if (!mounted || !_routeActive || _visibilityCheckScheduled || _leavingForEvents) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted || !_routeActive || _leavingForEvents) return;
      _updateVisibility();
    });
  }

  void _updateVisibility() {
    if (!_routeActive || _leavingForEvents) {
      _visibleFraction = 0;
      _pauseInvisible();
      return;
    }
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final top = render.localToGlobal(Offset.zero).dy;
    final bottom = top + render.size.height;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final visibleHeight =
        (math.min(bottom, screenHeight) - math.max(top, 0.0)).clamp(
          0.0,
          render.size.height,
        );
    _visibleFraction = render.size.height <= 0 ? 0 : visibleHeight / render.size.height;

    final videos = _videos(ref.read(videoEventsProvider));
    if (_visibleFraction >= 0.15 && _player == null && !_binding) {
      _bind(videos, autoPlay: false);
    }

    if (_visibleFraction >= 0.50) {
      if (_player == null) {
        _bind(videos, autoPlay: true);
      } else {
        _resumeVisible();
      }
    } else {
      _pauseInvisible();
    }
  }

  Future<void> _resumeVisible() async {
    final player = _player;
    if (!_routeActive ||
        _leavingForEvents ||
        player == null ||
        !player.value.isInitialized ||
        _visibleFraction < 0.50) {
      return;
    }
    await _applySound(player);
    await player.play();
    final current = _currentOf(_videos(ref.read(videoEventsProvider)));
    if (current != null) await _syncMusic(current);
  }

  void _pauseInvisible() {
    _player?.setVolume(0);
    _music?.setVolume(0);
    _player?.pause();
    _music?.pause();
  }

  void _onTick() {
    if (!_routeActive || _leavingForEvents || _binding || _advancing || _visibleFraction < 0.50) {
      return;
    }
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    final videos = _videos(ref.read(videoEventsProvider));
    if (videos.length <= 1) return;
    final pos = player.value.position;
    final dur = player.value.duration;
    final ended =
        player.value.isCompleted ||
        (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 80));
    if (!ended) return;
    _advancing = true;
    player.removeListener(_onTick);
    _index = (_index + 1) % videos.length;
    _bind(videos, autoPlay: true);
  }

  Future<void> _bind(List<Event> videos, {required bool autoPlay}) async {
    if (!_routeActive || _leavingForEvents || _binding || videos.isEmpty) return;
    if (_index >= videos.length) _index = 0;
    final event = videos[_index];
    final url = event.videoUrl?.trim();
    if (url == null || url.isEmpty) return;

    if (url == _boundUrl && _player != null && _player!.value.isInitialized) {
      if (autoPlay && _visibleFraction >= 0.50) await _resumeVisible();
      _advancing = false;
      return;
    }

    _binding = true;
    _boundUrl = url;
    final previous = _player;
    previous?.removeListener(_onTick);
    final next = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _player = next;

    try {
      await next.initialize();
      if (!mounted || !_routeActive || _boundUrl != url || _leavingForEvents) {
        await next.setVolume(0);
        await next.dispose();
        return;
      }
      await next.setLooping(videos.length == 1);
      await next.setVolume(0);
      next.addListener(_onTick);
      if (autoPlay && _visibleFraction >= 0.50) {
        await _resumeVisible();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted && videos.length > 1) {
        _index = (_index + 1) % videos.length;
        _boundUrl = null;
      }
      if (mounted) setState(() {});
    } finally {
      _binding = false;
      _advancing = false;
      await previous?.dispose();
      if (mounted &&
          _routeActive &&
          !_leavingForEvents &&
          _visibleFraction >= 0.50 &&
          _player == null) {
        _scheduleVisibilityCheck();
      }
    }
  }

  Future<void> _applySound(VideoPlayerController? player) async {
    if (player == null) return;
    await player.setVolume(!_routeActive || _leavingForEvents ? 0 : (_wantSound ? 1 : 0));
  }

  Future<void> _syncMusic(Event event) async {
    if (!_routeActive || _leavingForEvents || _visibleFraction < 0.50) {
      await _music?.setVolume(0);
      await _music?.pause();
      return;
    }
    final url = event.backgroundMusicUrl?.trim();
    if (url == null || url.isEmpty || !_wantSound) {
      await _music?.setVolume(0);
      await _music?.pause();
      return;
    }
    if (url == _musicUrl && _music != null && _music!.value.isInitialized) {
      await _music!.setVolume(0.5);
      await _music!.play();
      return;
    }
    final previous = _music;
    _musicUrl = url;
    final next = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _music = next;
    try {
      await next.initialize();
      if (!mounted ||
          !_routeActive ||
          _musicUrl != url ||
          _visibleFraction < 0.50 ||
          _leavingForEvents) {
        await next.setVolume(0);
        await next.dispose();
        return;
      }
      await next.setLooping(true);
      await next.setVolume(0.5);
      await next.play();
    } catch (_) {
      await next.dispose();
      if (identical(_music, next)) {
        _music = null;
        _musicUrl = null;
      }
    } finally {
      await previous?.dispose();
    }
  }

  void _advance(List<Event> videos, int delta) {
    if (videos.isEmpty || _binding || _leavingForEvents || !_routeActive) return;
    _index = (_index + delta) % videos.length;
    if (_index < 0) _index += videos.length;
    _boundUrl = null;
    _bind(videos, autoPlay: _visibleFraction >= 0.50);
  }

  void _toggleSound() {
    if (!_routeActive || _leavingForEvents) return;
    AppHaptics.selection();
    unlockDeckMedia();
    final nextOn = !ref.read(deckSoundOnProvider);
    ref.read(deckSoundOnProvider.notifier).setSoundOn(nextOn);
    final event = _currentOf(_videos(ref.read(videoEventsProvider)));
    _player?.setVolume(nextOn && _visibleFraction >= 0.50 ? 1 : 0);
    if (nextOn && _visibleFraction >= 0.50) {
      _player?.play();
      if (event != null) _syncMusic(event);
    } else {
      _music?.pause();
    }
  }

  Future<void> _openEvents(List<Event> videos) async {
    if (_leavingForEvents || !_routeActive) return;
    final current = _currentOf(videos);
    final player = _player;
    final music = _music;
    final position = player != null && player.value.isInitialized
        ? player.value.position
        : Duration.zero;

    if (current != null) {
      EventPreviewHandoff.set(eventId: current.id, position: position);
    } else {
      EventPreviewHandoff.clear();
    }

    _leavingForEvents = true;
    _visibleFraction = 0;
    player?.removeListener(_onTick);
    _player = null;
    _music = null;
    _boundUrl = null;
    _musicUrl = null;

    try {
      await player?.setVolume(0);
      await music?.setVolume(0);
      await player?.pause();
      await music?.pause();
      await player?.dispose();
      await music?.dispose();
    } catch (_) {
      // The route change is more important than a native player already closing.
    }
    if (!mounted) return;
    AppHaptics.medium();
    widget.onTap?.call();
  }

  Widget _fallbackMedia(Event? current) {
    final imageUrl = current?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return imageUrl.startsWith('assets/')
          ? Image.asset(imageUrl, fit: BoxFit.cover)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Image.asset(
                AppAssets.filterEvents,
                fit: BoxFit.cover,
              ),
            );
    }
    return Image.asset(AppAssets.filterEvents, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final apiVideos = ref.watch(videoEventsProvider);
    final videos = _videos(apiVideos);
    final soundOn = ref.watch(deckSoundOnProvider);

    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      if (_routeActive && !_leavingForEvents && _visibleFraction >= 0.50) {
        _applySound(_player);
        final event = _currentOf(videos);
        if (on && event != null) {
          _syncMusic(event);
        } else {
          _music?.pause();
        }
      } else {
        _pauseInvisible();
      }
    });

    ref.listen<List<Event>>(videoEventsProvider, (_, next) {
      if (_routeActive && !_leavingForEvents && _visibleFraction >= 0.15) {
        _bind(_videos(next), autoPlay: _visibleFraction >= 0.50);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleVisibilityCheck());

    final current = _currentOf(videos);
    final ready = _player != null && _player!.value.isInitialized;
    final segmentCount = videos.isEmpty ? 1 : videos.length.clamp(1, 8);

    final media = Stack(
      fit: StackFit.expand,
      children: [
        _fallbackMedia(current),
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _player!.value.size.width,
              height: _player!.value.size.height,
              child: VideoPlayer(_player!),
            ),
          ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEvents(videos),
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final gesture = velocity.abs() >= 100 ? velocity : _dragDx;
        if ((gesture.abs() >= 8 || _dragDx.abs() >= 8) && videos.length > 1) {
          AppHaptics.selection();
          _advance(videos, gesture < 0 ? 1 : -1);
        }
        _dragDx = 0;
      },
      child: ClipRRect(
        borderRadius: AppTheme.qfNeoFrameRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(_clarityMatrix),
              child: media,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x05000000),
                    Colors.transparent,
                    Color(0x52000000),
                  ],
                  stops: [0, 0.72, 1],
                ),
              ),
            ),
            if (!ready)
              Center(
                child: Icon(
                  Icons.celebration_outlined,
                  color: const Color(0xA6FFFFFF),
                  size: kIsWeb ? 36 : 40,
                ),
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
                      duration: const Duration(milliseconds: 150),
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
              top: 0,
              right: 0,
              child: EventMuteButton(soundOn: soundOn, onToggle: _toggleSound),
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
                    current?.title ?? 'Discover Local',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xE6FFFFFF),
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
