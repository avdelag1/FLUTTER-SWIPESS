import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/event_connect.dart';
import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/event_preview_handoff.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/event_mute_button.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/promote_cta_card.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// Full-screen, Reels-style event deck.
///
/// Events enters with all controls visible. In automatic mode they fade away
/// after seven seconds of inactivity, matching the listing swipe-deck rhythm.
/// The eye control is a deliberate pin: first tap keeps every control visible
/// indefinitely; the second tap releases the pin and hides them immediately.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  static const _chromeVisibleDuration = Duration(seconds: 7);

  final _pages = PageController();
  int _index = 0;
  String _category = 'All';
  bool _eventChromeVisible = true;
  bool _chromePinned = false;
  String? _handoffEventId;
  Duration? _handoffPosition;
  bool _handoffPageApplied = false;
  Timer? _chromeAutoHide;

  @override
  void initState() {
    super.initState();
    final handoff = EventPreviewHandoff.take();
    _handoffEventId = handoff?.eventId;
    _handoffPosition = handoff?.position;
    WidgetsBinding.instance.addPostFrameCallback((_) => _enterEvents());
  }

  @override
  void dispose() {
    _chromeAutoHide?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _enterEvents() {
    if (!mounted) return;
    _chromePinned = false;
    _showChrome(scheduleHide: true);
  }

  void _showChrome({bool scheduleHide = true}) {
    if (!mounted) return;
    _chromeAutoHide?.cancel();
    if (!_eventChromeVisible) setState(() => _eventChromeVisible = true);
    ref.read(chromeVisibilityProvider.notifier).show();
    if (scheduleHide && !_chromePinned) _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _chromeAutoHide?.cancel();
    if (_chromePinned || !_eventChromeVisible) return;
    _chromeAutoHide = Timer(_chromeVisibleDuration, () {
      if (mounted && !_chromePinned) _hideChrome();
    });
  }

  void _hideChrome() {
    _chromeAutoHide?.cancel();
    if (!mounted) return;
    if (_eventChromeVisible) setState(() => _eventChromeVisible = false);
    ref.read(chromeVisibilityProvider.notifier).hide();
  }

  void _toggleChromePin() {
    AppHaptics.light();
    if (_chromePinned) {
      _chromePinned = false;
      _hideChrome();
      return;
    }
    _chromePinned = true;
    _showChrome(scheduleHide: false);
  }

  void _handleSurfaceTap() {
    if (_chromePinned) return;
    AppHaptics.light();
    if (_eventChromeVisible) {
      _hideChrome();
    } else {
      _showChrome(scheduleHide: true);
    }
  }

  void _registerChromeActivity() {
    if (_chromePinned) {
      _showChrome(scheduleHide: false);
    } else if (_eventChromeVisible) {
      _scheduleAutoHide();
    }
  }

  void _prepareToLeaveEvents() {
    _chromeAutoHide?.cancel();
    _chromePinned = false;
    ref.read(chromeVisibilityProvider.notifier).show();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredEventsProvider);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: async.when(
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
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _category = 'All');
                            ref
                                .read(selectedCategoryProvider.notifier)
                                .setCategory('All');
                          },
                          child: const Text('Show all'),
                        ),
                      ],
                    ),
                  );
                }

                if (!_handoffPageApplied && _handoffEventId != null) {
                  final targetIndex = events.indexWhere(
                    (e) => e.id == _handoffEventId,
                  );
                  _handoffPageApplied = true;
                  if (targetIndex >= 0) {
                    _index = targetIndex;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || !_pages.hasClients) return;
                      _pages.jumpToPage(targetIndex);
                    });
                  }
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pages,
                      scrollDirection: Axis.vertical,
                      physics: const PageScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      allowImplicitScrolling: false,
                      itemCount: events.length + 1,
                      onPageChanged: (i) {
                        AppHaptics.selection();
                        setState(() => _index = i);
                        _registerChromeActivity();
                      },
                      itemBuilder: (context, i) {
                        if (i == events.length) {
                          return PromoteCTACard(
                            onPromote: () =>
                                context.push(AppPaths.clientAdvertise),
                          );
                        }
                        final event = events[i];
                        final active = i == _index;
                        final near = (i - _index).abs() <= 1;
                        return _EventStoryPage(
                          event: event,
                          active: active,
                          shouldLoadVideo: near,
                          siblings: events,
                          chromeVisible: _eventChromeVisible,
                          initialPosition: event.id == _handoffEventId
                              ? _handoffPosition
                              : null,
                          onToggleChrome: _handleSurfaceTap,
                          onChromeInteraction: _registerChromeActivity,
                          onOpen: () {
                            _registerChromeActivity();
                            context.push(AppPaths.exploreEvent(event.id));
                          },
                        );
                      },
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_eventChromeVisible,
                        child: AnimatedOpacity(
                          opacity: _eventChromeVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: Stack(
                            children: [
                              Positioned(
                                top: 4,
                                left: 4,
                                right: 0,
                                height: 66,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: 3,
                                      child: _TopIcon(
                                        icon: Icons.arrow_back_rounded,
                                        color: Colors.white,
                                        onTap: () {
                                          _prepareToLeaveEvents();
                                          if (context.canPop()) {
                                            context.pop();
                                          } else {
                                            context.go(
                                              AppPaths.clientDashboard,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      left: 46,
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: ShaderMask(
                                        blendMode: BlendMode.dstIn,
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black,
                                                Colors.black,
                                                Colors.transparent,
                                              ],
                                              stops: [0, 0.07, 0.91, 1],
                                            ).createShader(bounds),
                                        child: ListView(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(
                                            parent:
                                                AlwaysScrollableScrollPhysics(),
                                          ),
                                          padding: const EdgeInsets.only(
                                            left: 10,
                                            right: 22,
                                          ),
                                          children: [
                                            for (final c in ref.watch(
                                              eventCategoriesProvider,
                                            ))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 7,
                                                ),
                                                child: _EventCategoryRing(
                                                  category: c,
                                                  active: _category == c.key,
                                                  onTap: () {
                                                    AppHaptics.light();
                                                    _registerChromeActivity();
                                                    setState(() {
                                                      _category = c.key;
                                                      _index = 0;
                                                    });
                                                    ref
                                                        .read(
                                                          selectedCategoryProvider
                                                              .notifier,
                                                        )
                                                        .setCategory(c.key);
                                                    if (_pages.hasClients) {
                                                      _pages.jumpToPage(0);
                                                    }
                                                  },
                                                ),
                                              ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 10,
                                              ),
                                              child: _EventCategoryRing(
                                                category:
                                                    const EventFeedCategory(
                                                      key: 'likes',
                                                      label: 'My Likes',
                                                      icon: Icons.favorite_rounded,
                                                      image:
                                                          'assets/filters/events.jpg',
                                                      color: Color(0xFFEC4899),
                                                    ),
                                                active: false,
                                                onTap: () {
                                                  AppHaptics.light();
                                                  _registerChromeActivity();
                                                  context.push(
                                                    AppPaths.exploreEventsLikes,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            right: 14,
            bottom: bottomSafe + 18,
            child: _FocusOrb(
              controlsVisible: _eventChromeVisible,
              pinned: _chromePinned,
              onTap: _toggleChromePin,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusOrb extends StatelessWidget {
  const _FocusOrb({
    required this.controlsVisible,
    required this.pinned,
    required this.onTap,
  });
  final bool controlsVisible;
  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: pinned
          ? 'Hide event controls and release focus lock'
          : 'Keep event controls visible',
      child: BreathingWidget(
        duration: const Duration(milliseconds: 1800),
        minOpacity: .48,
        maxOpacity: .92,
        child: GestureDetector(
          onTap: onTap,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: pinned
                      ? Colors.white.withAlpha(45)
                      : Colors.black.withAlpha(54),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: pinned
                        ? Colors.white.withAlpha(150)
                        : Colors.white.withAlpha(72),
                    width: pinned ? 1 : .7,
                  ),
                ),
                child: Icon(
                  pinned || controlsVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(62),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(58), width: .7),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
        ),
      ),
    );
  }
}

class _EventCategoryRing extends StatelessWidget {
  const _EventCategoryRing({
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
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1 : .94,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: active
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                        )
                      : null,
                  color: active ? null : Colors.black.withAlpha(96),
                  border: active
                      ? null
                      : Border.all(
                          color: Colors.white.withAlpha(76),
                          width: .7,
                        ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEB4898).withAlpha(70),
                            blurRadius: 10,
                            spreadRadius: -1,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0A0A0B),
                      width: 1.5,
                    ),
                    color: const Color(0xFF1A1A1B),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: category.image.startsWith('assets/')
                      ? Image.asset(
                          category.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            category.icon,
                            size: 14,
                            color: Colors.white,
                          ),
                        )
                      : Image.network(
                          category.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            category.icon,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: active ? Colors.white : Colors.white.withAlpha(218),
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                fontSize: 9,
                letterSpacing: 0.12,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: active ? 12 : 3,
              height: 2,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFF4D8D)
                    : Colors.white.withAlpha(42),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventStoryPage extends ConsumerStatefulWidget {
  const _EventStoryPage({
    required this.event,
    required this.active,
    required this.shouldLoadVideo,
    required this.siblings,
    required this.chromeVisible,
    required this.onToggleChrome,
    required this.onChromeInteraction,
    required this.onOpen,
    this.initialPosition,
  });

  final Event event;
  final bool active;
  final bool shouldLoadVideo;
  final List<Event> siblings;
  final bool chromeVisible;
  final Duration? initialPosition;
  final VoidCallback onToggleChrome;
  final VoidCallback onChromeInteraction;
  final VoidCallback onOpen;

  @override
  ConsumerState<_EventStoryPage> createState() => _EventStoryPageState();
}

class _EventStoryPageState extends ConsumerState<_EventStoryPage> {
  VideoPlayerController? _player;
  bool? _favoritedOverride;
  bool _didApplyInitialPosition = false;

  Event get event => widget.event;

  bool get _hasVideo =>
      event.videoUrl != null && event.videoUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.shouldLoadVideo && _hasVideo) _bindVideo();
  }

  @override
  void didUpdateWidget(covariant _EventStoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldLoadVideo && _hasVideo && _player == null) {
      _bindVideo();
    }
    if (!widget.shouldLoadVideo && _player != null) {
      _player?.dispose();
      _player = null;
    }
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    if (widget.active) {
      p.play();
    } else {
      p.pause();
    }
    final soundOn = ref.read(deckSoundOnProvider);
    p.setVolume(soundOn ? 1 : 0);
  }

  Future<void> _bindVideo() async {
    final url = event.videoUrl;
    if (url == null) return;
    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = next;
    try {
      await next.initialize();
      await next.setLooping(true);
      final initial = widget.initialPosition;
      if (!_didApplyInitialPosition &&
          initial != null &&
          initial > Duration.zero) {
        final duration = next.value.duration;
        var safePosition = initial;
        if (duration > const Duration(milliseconds: 120) &&
            initial >= duration) {
          safePosition = duration - const Duration(milliseconds: 120);
        }
        if (safePosition > Duration.zero) {
          await next.seekTo(safePosition);
        }
        _didApplyInitialPosition = true;
      }
      final soundOn = ref.read(deckSoundOnProvider);
      await next.setVolume(soundOn ? 1 : 0);
      if (widget.active) await next.play();
      if (mounted) setState(() {});
    } catch (_) {
      await next.dispose();
      if (_player == next) _player = null;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    widget.onChromeInteraction();
    final current =
        _favoritedOverride ??
        (ref.read(eventFavoriteProvider(event.id)).value ?? false);
    setState(() => _favoritedOverride = !current);
    AppHaptics.medium();
    try {
      await ref
          .read(eventRepositoryProvider)
          .setFavorited(event.id, favorited: !current);
      ref.invalidate(eventFavoriteProvider(event.id));
      ref.invalidate(favoritedEventsProvider);
    } catch (_) {
      setState(() => _favoritedOverride = current);
    }
  }

  Future<void> _share() async {
    widget.onChromeInteraction();
    AppHaptics.light();
    await Clipboard.setData(
      ClipboardData(
        text: 'Check out ${event.title} on Swipess! ${event.shareUrl}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Event link copied')));
  }

  Future<void> _whatsApp() async {
    widget.onChromeInteraction();
    if (!event.hasWhatsApp) {
      widget.onOpen();
      return;
    }
    await EventConnect.open(
      EventConnect.whatsAppUri(
        event.organizerWhatsapp,
        message: 'Hola, vi tu evento "${event.title}" en Swipess 🔥',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorited =
        _favoritedOverride ??
        (ref.watch(eventFavoriteProvider(event.id)).value ?? false);
    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      _player?.setVolume(on ? 1 : 0);
      if (on && widget.active) _player?.play();
    });
    final bottom = MediaQuery.paddingOf(context).bottom;
    final player = _player;
    final ready = player != null && player.value.isInitialized;
    final image = event.gallery.isNotEmpty
        ? event.gallery.first
        : (event.imageUrl ?? '');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggleChrome,
      onDoubleTap: _toggleFavorite,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: player.value.size.width,
                height: player.value.size.height,
                child: VideoPlayer(player),
              ),
            )
          else if (image.isNotEmpty)
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF16161C)),
            )
          else
            const ColoredBox(color: Color(0xFF16161C)),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22000000),
                    Color(0x00000000),
                    Color(0x72000000),
                  ],
                  stops: [0, 0.58, 1],
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !widget.chromeVisible,
            child: AnimatedOpacity(
              opacity: widget.chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    right: 12,
                    bottom: bottom + 110,
                    child: Column(
                      children: [
                        _RailBtn(
                          icon: favorited
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: favorited
                              ? const Color(0xFFF43F5E)
                              : Colors.white,
                          onTap: _toggleFavorite,
                        ),
                        const SizedBox(height: 10),
                        EventMuteButton(
                          soundOn: ref.watch(deckSoundOnProvider),
                          onToggle: () {
                            widget.onChromeInteraction();
                            final next = !ref.read(deckSoundOnProvider);
                            ref
                                .read(deckSoundOnProvider.notifier)
                                .setSoundOn(next);
                            _player?.setVolume(next ? 1 : 0);
                            if (next) _player?.play();
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(86),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withAlpha(44),
                              width: .7,
                            ),
                          ),
                          child: Column(
                            children: [
                              _RailBtn(
                                icon: Icons.info_outline_rounded,
                                size: 42,
                                onTap: widget.onOpen,
                              ),
                              _RailBtn(
                                icon: Icons.chat_rounded,
                                size: 42,
                                onTap: _whatsApp,
                              ),
                              _RailBtn(
                                icon: Icons.share_rounded,
                                size: 42,
                                onTap: _share,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 88,
                    bottom: bottom + 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Pill(
                              label: event.category.toUpperCase(),
                              color: AppTheme.brandPrimary,
                            ),
                            if (event.isFree) ...[
                              const SizedBox(width: 6),
                              const _Pill(
                                label: 'FREE',
                                color: Color(0xFF34D399),
                              ),
                            ],
                            if (_hasVideo) ...[
                              const SizedBox(width: 6),
                              const _Pill(
                                label: 'VIDEO',
                                color: Color(0xFF38BDF8),
                              ),
                            ],
                            if (event.discountTag != null) ...[
                              const SizedBox(width: 6),
                              _Pill(
                                label: event.discountTag!.toUpperCase(),
                                color: const Color(0xFFFBBF24),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          event.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            height: 1.05,
                            letterSpacing: -0.6,
                            shadows: const [
                              Shadow(blurRadius: 12, color: Colors.black),
                            ],
                          ),
                        ),
                        if (event.organizerName != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'by ${event.organizerName}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (event.promoText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            event.promoText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withAlpha(220),
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (event.eventDate != null)
                              _MetaChip(
                                icon: Icons.calendar_today_rounded,
                                label: DateFormat('MMM d · h:mm a')
                                    .format(event.eventDate!.toLocal()),
                              ),
                            if (event.location != null)
                              _MetaChip(
                                icon: Icons.location_on_rounded,
                                label: event.location!,
                              ),
                            if (!event.isFree && event.priceText != null)
                              _MetaChip(
                                icon: Icons.confirmation_number_rounded,
                                label: event.priceText!,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _chromePinnedHelp,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _chromePinnedHelp =
      'Swipe up for next · eye keeps controls visible';
}

class _RailBtn extends StatelessWidget {
  const _RailBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.size = 48,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(76),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(44), width: .7),
        ),
        child: Icon(icon, color: color, size: size > 44 ? 21 : 18),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(42), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFFB923C)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
