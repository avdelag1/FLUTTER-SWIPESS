import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/utils/event_connect.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/event_preview_handoff.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/promote_cta_card.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// Reels-style Events feed.
///
/// Event categories stay out of the way until the top-right menu is opened.
/// Likes sit beside that menu, while the per-event action rail stays tight to
/// the right edge. Dashboard video previews can hand their buffered player into
/// this screen so opening Events does not restart the same stream.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  static const _chromeTimeout = Duration(milliseconds: 5600);

  final PageController _pages = PageController();
  int _index = 0;
  String _category = 'All';
  late bool _chromeVisible;
  bool _chromePinned = false;
  bool _categoryMenuOpen = false;
  Timer? _hideTimer;

  String? _handoffEventId;
  Duration? _handoffPosition;
  VideoPlayerController? _handoffController;
  bool _handoffWantSound = false;
  bool _handoffApplied = false;
  VideoPlayerController? _preloadedNext;
  int? _preloadedNextIndex;

  @override
  void initState() {
    super.initState();
    _category = ref.read(selectedCategoryProvider);
    final handoff = EventPreviewHandoff.take();
    _handoffEventId = handoff?.eventId;
    _handoffPosition = handoff?.position;
    _handoffController = handoff?.controller;
    _handoffWantSound = handoff?.wantSound ?? false;
    if (_handoffWantSound) {
      unlockDeckMedia();
      ref.read(deckSoundOnProvider.notifier).preserveAudibleHandoff();
    }

    _chromeVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showChrome();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _preloadedNext?.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _preloadNextEventVideo(List<Event> events) {
    if (events.isEmpty) return;
    final nextIndex = _index + 1;
    if (nextIndex >= events.length) return;
    if (_preloadedNextIndex == nextIndex &&
        _preloadedNext != null &&
        _preloadedNext!.value.isInitialized) {
      return;
    }

    unawaited(() async {
      final event = events[nextIndex];
      final url = event.videoUrl?.trim();
      if (url == null || url.isEmpty) return;

      final player = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await player.initialize();
        await player.setLooping(true);
        await player.setVolume(0);
        if (!mounted || _index + 1 != nextIndex) {
          await player.dispose();
          return;
        }
        final old = _preloadedNext;
        _preloadedNext = player;
        _preloadedNextIndex = nextIndex;
        await old?.dispose();
      } catch (_) {
        await player.dispose();
      }
    }());
  }

  void _consumePreparedVideo(int index) {
    if (_preloadedNextIndex != index) return;
    _preloadedNext = null;
    _preloadedNextIndex = null;
  }

  void _showChrome({bool schedule = true}) {
    if (!mounted) return;
    _hideTimer?.cancel();
    if (!_chromeVisible) setState(() => _chromeVisible = true);
    ref.read(chromeVisibilityProvider.notifier).show();
    if (schedule && !_chromePinned && !_categoryMenuOpen) {
      _hideTimer = Timer(_chromeTimeout, _hideChrome);
    }
  }

  void _hideChrome() {
    _hideTimer?.cancel();
    if (!mounted || _chromePinned || _categoryMenuOpen) return;
    if (_chromeVisible) setState(() => _chromeVisible = false);
    ref.read(chromeVisibilityProvider.notifier).hide();
  }

  void _toggleChrome() {
    if (_categoryMenuOpen) {
      AppHaptics.light();
      setState(() => _categoryMenuOpen = false);
      _showChrome();
      return;
    }
    if (_chromePinned) return;
    AppHaptics.light();
    if (_chromeVisible) {
      _hideChrome();
    } else {
      _showChrome();
    }
  }

  void _togglePin() {
    AppHaptics.light();
    _hideTimer?.cancel();
    if (_chromeVisible) {
      setState(() {
        _chromeVisible = false;
        _chromePinned = false;
        _categoryMenuOpen = false;
      });
    } else {
      setState(() {
        _chromeVisible = true;
        _chromePinned = true;
      });
      ref.read(chromeVisibilityProvider.notifier).show();
    }
  }

  void _touchChrome() {
    if (!_chromePinned && _chromeVisible && !_categoryMenuOpen) _showChrome();
  }

  void _toggleCategoryMenu() {
    AppHaptics.light();
    _hideTimer?.cancel();
    setState(() {
      _categoryMenuOpen = !_categoryMenuOpen;
      _chromeVisible = true;
    });
    ref.read(chromeVisibilityProvider.notifier).show();
    if (!_categoryMenuOpen) _showChrome();
  }

  void _selectCategory(EventFeedCategory category) {
    AppHaptics.selection();
    setState(() {
      _category = category.key;
      _categoryMenuOpen = false;
      _index = 0;
    });
    ref.read(selectedCategoryProvider.notifier).setCategory(category.key);
    if (_pages.hasClients) _pages.jumpToPage(0);
    _showChrome();
  }

  void _goBack(BuildContext context) {
    ref.read(chromeVisibilityProvider.notifier).show();
    NavBack.popOrGo(context, fallbackPath: AppPaths.clientDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredEventsProvider);
    final categories = ref.watch(eventCategoriesProvider);
    final likedCount = ref.watch(favoritedEventsProvider).value?.length ?? 0;
    final safe = MediaQuery.paddingOf(context);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(eventsListProvider.notifier).refresh(),
                child: const Text('Could not load events — retry'),
              ),
            ),
            data: (events) {
              if (events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No $_category events',
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () => _selectCategory(categories.first),
                        child: const Text('Show all'),
                      ),
                    ],
                  ),
                );
              }

              if (!_handoffApplied && _handoffEventId != null) {
                _handoffApplied = true;
                final target = events.indexWhere(
                  (event) => event.id == _handoffEventId,
                );
                if (target >= 0) {
                  _index = target;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _pages.hasClients) _pages.jumpToPage(target);
                  });
                }
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _preloadNextEventVideo(events);
              });

              return PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                itemCount: events.length + 1,
                onPageChanged: (index) {
                  AppHaptics.selection();
                  setState(() {
                    _index = index;
                    _categoryMenuOpen = false;
                  });
                  _touchChrome();
                  _preloadNextEventVideo(events);
                },
                itemBuilder: (context, index) {
                  if (index == events.length) {
                    return PromoteCTACard(
                      onPromote: () => context.push(AppPaths.clientAdvertise),
                    );
                  }

                  final event = events[index];
                  return _EventPage(
                    event: event,
                    active: index == _index,
                    shouldLoadVideo: (index - _index).abs() <= 1,
                    chromeVisible: _chromeVisible,
                    preparedController: _preloadedNextIndex == index
                        ? _preloadedNext
                        : null,
                    onPreparedConsumed: () => _consumePreparedVideo(index),
                    initialPosition: event.id == _handoffEventId
                        ? _handoffPosition
                        : null,
                    initialController: event.id == _handoffEventId
                        ? _handoffController
                        : null,
                    handoffWantSound:
                        event.id == _handoffEventId && _handoffWantSound,
                    onToggleChrome: _toggleChrome,
                    onChromeInteraction: _touchChrome,
                    onOpen: () {
                      _touchChrome();
                      context.push(AppPaths.exploreEvent(event.id));
                    },
                  );
                },
              );
            },
          ),

          // Back must stay tappable even when event chrome auto-hides.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 3, 0, 0),
                child: _EdgeGlassButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: 'Back',
                  onTap: () => _goBack(context),
                ),
              ),
            ),
          ),

          // Saved events + category menu hide with immersive chrome.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: AnimatedSlide(
                offset: _chromeVisible ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 3, 2, 0),
                      child: Row(
                        children: [
                          const SizedBox(width: 48),
                          const Spacer(),
                          _SavedEventsButton(
                            count: likedCount,
                            onTap: () {
                              _touchChrome();
                              context.push(AppPaths.exploreEventsLikes);
                            },
                          ),
                          const SizedBox(width: 3),
                          _EdgeGlassButton(
                            icon: _categoryMenuOpen
                                ? Icons.close_rounded
                                : Icons.tune_rounded,
                            tooltip: 'Event categories',
                            active: _categoryMenuOpen,
                            onTap: _toggleCategoryMenu,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Categories materialize from the right edge and flow left. They sit
          // almost flush with the viewport instead of living permanently in a
          // padded top rail.
          Positioned(
            top: safe.top + 45,
            left: 42,
            right: 1,
            height: 61,
            child: IgnorePointer(
              ignoring: !_chromeVisible || !_categoryMenuOpen,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(.22, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _categoryMenuOpen
                    ? Align(
                        key: const ValueKey('event-category-menu-open'),
                        alignment: Alignment.topRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final category in categories.reversed) ...[
                                _CategoryBubble(
                                  category: category,
                                  active: _category == category.key,
                                  onTap: () => _selectCategory(category),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('event-category-menu-closed'),
                      ),
              ),
            ),
          ),

          Positioned(
            right: 1,
            bottom: safe.bottom + 32,
            child: _EdgeGlassButton(
              icon: _chromeVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              tooltip: _chromeVisible ? 'Hide controls' : 'Show controls',
              size: 34,
              onTap: _togglePin,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventPage extends ConsumerStatefulWidget {
  const _EventPage({
    required this.event,
    required this.active,
    required this.shouldLoadVideo,
    required this.chromeVisible,
    required this.onToggleChrome,
    required this.onChromeInteraction,
    required this.onOpen,
    this.initialPosition,
    this.initialController,
    this.handoffWantSound = false,
    this.preparedController,
    this.onPreparedConsumed,
  });

  final Event event;
  final bool active;
  final bool shouldLoadVideo;
  final bool chromeVisible;
  final VoidCallback onToggleChrome;
  final VoidCallback onChromeInteraction;
  final VoidCallback onOpen;
  final Duration? initialPosition;
  final VideoPlayerController? initialController;
  final bool handoffWantSound;
  final VideoPlayerController? preparedController;
  final VoidCallback? onPreparedConsumed;

  @override
  ConsumerState<_EventPage> createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<_EventPage>
    with WidgetsBindingObserver {
  Future<void> _playReliably(VideoPlayerController? player) async {
    if (player == null || !player.value.isInitialized) return;

    final soundOn = ref.read(deckSoundOnProvider);
    final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
    final wantsSound =
        soundOn && (unlocked || !kIsWeb || _sessionAudioUnlocked);
    if (wantsSound) unlockDeckMedia();
    try {
      // Start muted first. This is accepted by browser autoplay policies and
      // also gives native players a deterministic first frame before audio.
      await player.setVolume(0);
      await player.play();
      if (wantsSound) await player.setVolume(1);
    } catch (_) {
      // A play() rejection is not an initialization failure. Keep the decoder
      // mounted so the first frame remains visible and a user tap can retry.
      try {
        await player.setVolume(0);
      } catch (_) {}
    }
  }

  VideoPlayerController? _player;
  bool? _favoritedOverride;
  bool _busy = false;
  bool _initialApplied = false;
  bool _appActive = true;
  bool _videoLoading = false;
  bool _videoFailed = false;
  bool _sessionAudioUnlocked = !kIsWeb;
  IconData? _playbackFeedback;
  Timer? _playbackFeedbackTimer;

  Event get event => widget.event;
  List<String> get _media {
    final out = <String>[];
    final v = event.videoUrl;
    if (v != null && v.trim().isNotEmpty) out.add(v.trim());
    for (final img in event.gallery) {
      if (!out.contains(img)) out.add(img);
    }
    if (out.isEmpty &&
        event.imageUrl != null &&
        event.imageUrl!.trim().isNotEmpty) {
      out.add(event.imageUrl!.trim());
    }
    return out;
  }

  bool _isVideo(String value) {
    // `video_url` is authoritative. CDN/Supabase URLs do not have to expose a
    // file extension, so never downgrade a declared event video into an image
    // just because its public URL is opaque.
    final declared = event.videoUrl?.trim();
    if (declared != null && declared.isNotEmpty && value.trim() == declared) {
      return true;
    }

    final uri = Uri.tryParse(value);
    final path = (uri?.path ?? value).toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.webm') ||
        path.endsWith('.mov') ||
        path.contains('/videos/');
  }

  int _mediaIndex = 0;
  late final PageController _mediaPages = PageController();

  bool get _hasVideo {
    final m = _media;
    if (m.isEmpty) return false;
    return _isVideo(m[_mediaIndex % m.length]);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.handoffWantSound) {
      _sessionAudioUnlocked = true;
      unlockDeckMedia();
      ref.read(deckSoundOnProvider.notifier).preserveAudibleHandoff();
    }
    final transferred = widget.initialController;
    if (transferred != null && transferred.value.isInitialized) {
      _player = transferred;
      _initialApplied = true;
      unawaited(_adoptTransferredVideo(transferred));
    } else if (widget.preparedController != null &&
        widget.preparedController!.value.isInitialized) {
      _player = widget.preparedController;
      widget.onPreparedConsumed?.call();
      unawaited(_adoptTransferredVideo(widget.preparedController!));
    } else if (widget.shouldLoadVideo && _hasVideo) {
      unawaited(_bindVideo());
    }
  }

  @override
  void didUpdateWidget(covariant _EventPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shouldLoadVideo && _hasVideo && _player == null) {
      final transferred = widget.initialController;
      if (transferred != null && transferred.value.isInitialized) {
        _player = transferred;
        _initialApplied = true;
        unawaited(_adoptTransferredVideo(transferred));
      } else if (widget.preparedController != null &&
          widget.preparedController!.value.isInitialized) {
        _player = widget.preparedController;
        widget.onPreparedConsumed?.call();
        unawaited(_adoptTransferredVideo(widget.preparedController!));
      } else {
        unawaited(_bindVideo());
      }
    }

    if (!widget.shouldLoadVideo && _player != null) {
      unawaited(_player?.dispose());
      _player = null;
    }

    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    if (widget.active) {
      unawaited(_playReliably(player));
    } else {
      unawaited(player.pause());
    }
  }

  Future<void> _adoptTransferredVideo(VideoPlayerController player) async {
    try {
      await player.setLooping(true);
      await player.setVolume(0);
      if (mounted && identical(_player, player)) {
        setState(() {
          _videoLoading = false;
          _videoFailed = false;
        });
      }
      if (widget.active && _appActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              widget.active &&
              _appActive &&
              identical(_player, player)) {
            unawaited(_playReliably(player));
          }
        });
      }
    } catch (_) {
      if (!mounted || !identical(_player, player)) return;
      try {
        await player.dispose();
      } catch (_) {}
      _player = null;
      setState(() => _videoFailed = true);
      if (widget.shouldLoadVideo && _hasVideo) unawaited(_bindVideo());
    }
  }

  Future<void> _bindVideo() async {
    if (_videoLoading) return;
    final media = _media;
    if (media.isEmpty) return;
    final url = media[_mediaIndex % media.length];
    if (!_isVideo(url)) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _videoFailed = true);
      return;
    }

    if (mounted) {
      setState(() {
        _videoLoading = true;
        _videoFailed = false;
      });
    }

    final previous = _player;
    final next = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _player = next;

    try {
      if (previous != null && !identical(previous, next)) {
        try {
          await previous.setVolume(0);
          await previous.pause();
        } catch (_) {}
        try {
          await previous.dispose();
        } catch (_) {}
      }

      await next.initialize();
      await next.setLooping(true);
      await next.setVolume(0);

      final current = _media;
      final stillCurrent =
          mounted &&
          widget.shouldLoadVideo &&
          current.isNotEmpty &&
          current[_mediaIndex % current.length] == url &&
          identical(_player, next);
      if (!stillCurrent) {
        try {
          await next.dispose();
        } catch (_) {}
        if (identical(_player, next)) _player = null;
        return;
      }

      if (!_initialApplied && widget.initialPosition != null) {
        final duration = next.value.duration;
        var target = widget.initialPosition!;
        if (duration > const Duration(milliseconds: 120) &&
            target >= duration) {
          target = duration - const Duration(milliseconds: 120);
        }
        if (target > Duration.zero) await next.seekTo(target);
        _initialApplied = true;
      }

      // Critical: publish `isInitialized` BEFORE awaiting play(). On web/PWA
      // the play future can be delayed by autoplay policy; the moving-picture
      // surface must still mount immediately instead of leaving a black card.
      if (mounted && identical(_player, next)) {
        setState(() {
          _videoLoading = false;
          _videoFailed = false;
        });
      }

      if (widget.active && _appActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              widget.active &&
              _appActive &&
              identical(_player, next)) {
            unawaited(_playReliably(next));
          }
        });
      }
    } catch (_) {
      try {
        await next.dispose();
      } catch (_) {}
      if (identical(_player, next)) _player = null;
      if (mounted) {
        setState(() {
          _videoLoading = false;
          _videoFailed = true;
        });
      }
    } finally {
      if (!mounted) return;
      if (_videoLoading && !identical(_player, next)) {
        setState(() => _videoLoading = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appActive = true;
        if (mounted && widget.active) unawaited(_resumeAfterBackground());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appActive = false;
        final player = _player;
        if (player != null) {
          unawaited(player.setVolume(0));
          unawaited(player.pause());
        }
        break;
    }
  }

  Future<void> _resumeAfterBackground() async {
    final player = _player;
    if (!mounted || !_appActive || !widget.active || player == null) return;
    await _playReliably(player);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackFeedbackTimer?.cancel();
    _player?.dispose();
    _mediaPages.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final player = _player;
    if (player == null || !player.value.isInitialized) {
      if (_hasVideo && widget.shouldLoadVideo) unawaited(_bindVideo());
      return;
    }

    final shouldPlay = !player.value.isPlaying;
    try {
      if (shouldPlay) {
        await _playReliably(player);
      } else {
        await player.pause();
      }
      if (!mounted) return;
      _playbackFeedbackTimer?.cancel();
      setState(
        () => _playbackFeedback = shouldPlay
            ? Icons.play_arrow_rounded
            : Icons.pause_rounded,
      );
      _playbackFeedbackTimer = Timer(const Duration(milliseconds: 620), () {
        if (mounted) setState(() => _playbackFeedback = null);
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_busy) return;
    widget.onChromeInteraction();

    final current =
        _favoritedOverride ??
        (ref.read(eventFavoriteProvider(event.id)).value ?? false);
    setState(() {
      _busy = true;
      _favoritedOverride = !current;
    });
    AppHaptics.medium();

    try {
      await ref
          .read(eventRepositoryProvider)
          .setFavorited(event.id, favorited: !current);
      ref.invalidate(eventFavoriteProvider(event.id));
      ref.invalidate(favoritedEventsProvider);
    } catch (_) {
      if (mounted) setState(() => _favoritedOverride = current);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    widget.onChromeInteraction();
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: 'Check out ${event.title} on Swipess! ${event.shareUrl}',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }

  Future<void> _contactOrganizer() async {
    widget.onChromeInteraction();
    if (event.hasWhatsApp) {
      await EventConnect.open(
        EventConnect.whatsAppUri(
          event.organizerWhatsapp,
          message: 'Hola, vi tu evento "${event.title}" en Swipess 🔥',
        ),
      );
    } else if ((event.organizerInstagram ?? '').isNotEmpty) {
      await EventConnect.open(
        EventConnect.instagramUri(event.organizerInstagram),
      );
    } else if ((event.organizerFacebook ?? '').isNotEmpty) {
      await EventConnect.open(
        EventConnect.facebookUri(event.organizerFacebook),
      );
    } else if ((event.organizerWebsite ?? '').isNotEmpty) {
      await EventConnect.open(EventConnect.websiteUri(event.organizerWebsite));
    } else {
      widget.onOpen(); // Fallback to info panel if no contact info
    }
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

  Widget _videoPoster(BuildContext context) {
    String? poster;
    final primary = event.imageUrl?.trim();
    if (primary != null && primary.isNotEmpty && !_isVideo(primary)) {
      poster = primary;
    }
    if (poster == null) {
      for (final candidate in event.gallery) {
        final value = candidate.trim();
        if (value.isNotEmpty && !_isVideo(value)) {
          poster = value;
          break;
        }
      }
    }

    if (poster == null) {
      return const ColoredBox(color: Color(0xFF16161C));
    }
    return Image.network(
      poster,
      fit: BoxFit.cover,
      cacheWidth: (MediaQuery.sizeOf(context).width * 2).round().clamp(
        640,
        1800,
      ),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ColoredBox(color: Color(0xFF16161C)),
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF16161C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorited =
        _favoritedOverride ??
        (ref.watch(eventFavoriteProvider(event.id)).value ?? false);
    final soundOn = ref.watch(deckSoundOnProvider);

    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      final player = _player;
      if (player == null || !player.value.isInitialized) return;
      final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
      final audible = on && (unlocked || !kIsWeb || _sessionAudioUnlocked);
      unawaited(player.setVolume(audible ? 1 : 0));
      if (widget.active && _appActive) unawaited(_playReliably(player));
    });

    final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;
    final effectiveSoundOn =
        soundOn && (unlocked || !kIsWeb || _sessionAudioUnlocked);
    final player = _player;
    final ready = player != null && player.value.isInitialized;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final cardExpanded = !widget.chromeVisible;
    final cardDuration = Duration(milliseconds: cardExpanded ? 680 : 420);
    final cardCurve = cardExpanded ? const Cubic(0.18, 1.16, 0.28, 1.0) : Curves.easeOutCubic;

    return AnimatedPadding(
      duration: cardDuration,
      curve: cardCurve,
      padding: EdgeInsets.fromLTRB(
        0,
        cardExpanded ? 0 : MediaQuery.paddingOf(context).top + 88,
        0,
        cardExpanded ? 0 : MediaQuery.paddingOf(context).bottom + 82,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
      // A single center tap must stay immediate. Favorite remains available
      // from the dedicated rail, so double-tap cannot delay play/pause.
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_media.isEmpty)
            const ColoredBox(color: Color(0xFF16161C))
          else
            PageView.builder(
              controller: _mediaPages,
              scrollDirection: Axis.horizontal,
              itemCount: _media.length,
              onPageChanged: (index) {
                setState(() => _mediaIndex = index);
                if (_hasVideo && widget.shouldLoadVideo) {
                  _bindVideo();
                } else if (_player != null) {
                  unawaited(_player?.pause());
                  unawaited(_player?.dispose());
                  _player = null;
                }
              },
              itemBuilder: (context, index) {
                final url = _media[index];
                final isVid = _isVideo(url);
                if (isVid) {
                  final activePlayer = index == _mediaIndex && ready
                      ? player
                      : null;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Keep the event artwork painted while the decoder warms
                      // so opening/swiping never flashes a dead black frame.
                      _videoPoster(context),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: activePlayer == null
                            ? SizedBox.expand(
                                key: ValueKey(
                                  'event-video-poster-${event.id}-$index',
                                ),
                              )
                            : RepaintBoundary(
                                key: ValueKey(
                                  'event-video-live-${event.id}-$index',
                                ),
                                child: _coverVideo(activePlayer),
                              ),
                      ),
                      if (index == _mediaIndex && !ready)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _videoFailed
                                    ? const Icon(
                                        Icons.play_circle_fill_rounded,
                                        key: ValueKey('event-video-retry'),
                                        color: Colors.white,
                                        size: 54,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 14,
                                          ),
                                        ],
                                      )
                                    : const SizedBox(
                                        key: ValueKey('event-video-loading'),
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }

                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: (MediaQuery.sizeOf(context).width * 2)
                      .round()
                      .clamp(640, 1800),
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF16161C)),
                );
              },
            ),

          if (_media.length > 1)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 100,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _media.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: i == _mediaIndex ? 14 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i == _mediaIndex
                            ? Colors.white
                            : Colors.white.withAlpha(100),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (ready)
            Positioned(
              left: 2,
              right: 2,
              bottom: bottom + 2,
              height: 24,
              child: _EventProgressScrubber(player: player),
            ),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x18000000),
                  Colors.transparent,
                  Color(0xB3000000),
                ],
                stops: [0, .52, 1],
              ),
            ),
          ),
          if (_playbackFeedback != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Icon(
                        _playbackFeedback,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Tight, bright, right-edge action rail. Saved-library navigation was
          // moved to the top-right header, so this rail contains only actions
          // for the current event.
          Positioned(
            right: 0,
            bottom: bottom + 80,
            child: Column(
              children: [
                IgnorePointer(
                  ignoring: !widget.chromeVisible,
                  child: AnimatedSlide(
                    offset: widget.chromeVisible
                        ? Offset.zero
                        : const Offset(.8, 0),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: widget.chromeVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Column(
                        children: [
                          _RailAction(
                            icon: favorited
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: favorited
                                ? AppTheme.brandPrimary
                                : Colors.white,
                            onTap: _toggleFavorite,
                          ),
                          const SizedBox(height: 8),
                          _RailAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: _contactOrganizer,
                          ),
                          const SizedBox(height: 8),
                          _RailAction(
                            icon: Icons.ios_share_rounded,
                            onTap: _share,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _RailAction(
                  icon: effectiveSoundOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  onTap: () {
                    widget.onChromeInteraction();
                    unlockDeckMedia();
                    _sessionAudioUnlocked = true;
                    final nextSoundOn = !effectiveSoundOn;
                    ref
                        .read(deckSoundOnProvider.notifier)
                        .setSoundOn(nextSoundOn);
                    if (mounted) setState(() {});
                    final player = _player;
                    if (player != null && player.value.isInitialized) {
                      unawaited(player.setVolume(nextSoundOn ? 1 : 0));
                      if (nextSoundOn && widget.active && _appActive) {
                        unawaited(_playReliably(player));
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          Positioned(
            left: 12,
            right: 48,
            bottom: bottom + 18,
            child: IgnorePointer(
              ignoring: !widget.chromeVisible,
              child: AnimatedSlide(
                offset: widget.chromeVisible
                    ? Offset.zero
                    : const Offset(0, .7),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: widget.chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          _MetaPill(label: event.category.toUpperCase()),
                          if (event.isFree) const _MetaPill(label: 'FREE'),
                          if (_hasVideo) const _MetaPill(label: 'VIDEO'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.03,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.7,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 12),
                          ],
                        ),
                      ),
                      if ((event.organizerName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'by ${event.organizerName}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if ((event.promoText ?? '').isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          event.promoText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.28,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          if (event.eventDate != null)
                            _InfoChip(
                              icon: Icons.calendar_today_rounded,
                              label: DateFormat('MMM d · h:mm a')
                                  .format(event.eventDate!.toLocal()),
                            ),
                          if ((event.location ?? '').isNotEmpty)
                            _InfoChip(
                              icon: Icons.location_on_rounded,
                              label: event.location!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    )));
  }
}

class _EventProgressScrubber extends StatelessWidget {
  const _EventProgressScrubber({required this.player});

  final VideoPlayerController player;

  Future<void> _seek(BuildContext context, double dx, double width) async {
    final value = player.value;
    if (!value.isInitialized || value.duration <= Duration.zero) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    await player.seekTo(
      Duration(milliseconds: (value.duration.inMilliseconds * ratio).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      builder: (context, value, _) {
        if (!value.isInitialized || value.duration <= Duration.zero) {
          return const SizedBox.shrink();
        }
        final progress =
            (value.position.inMilliseconds / value.duration.inMilliseconds)
                .clamp(0.0, 1.0);
        return LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            onTapDown: (details) => unawaited(
              _seek(context, details.localPosition.dx, constraints.maxWidth),
            ),
            onHorizontalDragUpdate: (details) => unawaited(
              _seek(context, details.localPosition.dx, constraints.maxWidth),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 5,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(color: Color(0x88FFFFFF), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth * progress - 5).clamp(
                        -5.0,
                        constraints.maxWidth - 5,
                      ),
                      top: -3,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4D78),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0xAAFF4D78), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SavedEventsButton extends StatelessWidget {
  const _SavedEventsButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Saved events, $count',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 42),
          padding: EdgeInsets.symmetric(horizontal: count > 0 ? 9 : 7),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(44), width: .7),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 12),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 20,
                color: AppTheme.brandPrimary,
                shadows: [
                  Shadow(
                    color: AppTheme.brandPrimary.withAlpha(153),
                    blurRadius: 8,
                  ),
                  Shadow(color: Color(0xCC000000), blurRadius: 3),
                ],
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFFFB3BE),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EdgeGlassButton extends StatelessWidget {
  const _EdgeGlassButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 38,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? Colors.white.withAlpha(38)
                : Colors.black.withAlpha(68),
            border: Border.all(
              color: Colors.white.withAlpha(active ? 94 : 42),
              width: .7,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 12),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size <= 34 ? 18 : 20,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final EventFeedCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 47,
        height: 59,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 39,
              height: 39,
              padding: EdgeInsets.all(active ? 2.2 : 1.2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.brandPrimary, AppTheme.brandPrimary2],
                      )
                    : null,
                color: active ? null : Colors.black.withAlpha(90),
                border: active
                    ? null
                    : Border.all(color: Colors.white.withAlpha(62), width: .7),
                boxShadow: const [
                  BoxShadow(color: Color(0x55000000), blurRadius: 10),
                ],
              ),
              child: ClipOval(
                child: category.image.startsWith('assets/')
                    ? Image.asset(
                        category.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _CategoryFallback(category),
                      )
                    : Image.network(
                        category.image,
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                        errorBuilder: (_, _, _) => _CategoryFallback(category),
                      ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : Colors.white.withAlpha(205),
                fontSize: 8,
                height: 1,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFallback extends StatelessWidget {
  const _CategoryFallback(this.category);

  final EventFeedCategory category;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: category.color,
      child: Icon(category.icon, size: 19, color: Colors.white),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: 22,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 9),
                Shadow(color: Colors.white24, blurRadius: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppTheme.brandPrimary.withAlpha(60),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(24), width: .5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
