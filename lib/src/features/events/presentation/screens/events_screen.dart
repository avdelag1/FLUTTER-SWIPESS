import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/event_connect.dart';
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

/// Reels-style Events feed with Instagram-like heart interactions.
///
/// Dashboard event previews can hand their already-buffered player into this
/// screen, so opening an event feels immediate instead of reconnecting to the
/// same video URL and buffering again.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  static const _chromeTimeout = Duration(seconds: 7);

  final PageController _pages = PageController();
  int _index = 0;
  String _category = 'All';
  late bool _chromeVisible;
  bool _chromePinned = false;
  Timer? _hideTimer;

  String? _handoffEventId;
  Duration? _handoffPosition;
  VideoPlayerController? _handoffController;
  bool _handoffApplied = false;

  @override
  void initState() {
    super.initState();
    final handoff = EventPreviewHandoff.take();
    _handoffEventId = handoff?.eventId;
    _handoffPosition = handoff?.position;
    _handoffController = handoff?.controller;

    // Always show chrome initially, then hide after 7 seconds
    _chromeVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showChrome();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _showChrome({bool schedule = true}) {
    if (!mounted) return;
    _hideTimer?.cancel();
    if (!_chromeVisible) setState(() => _chromeVisible = true);
    ref.read(chromeVisibilityProvider.notifier).show();
    if (schedule && !_chromePinned) {
      _hideTimer = Timer(_chromeTimeout, _hideChrome);
    }
  }

  void _hideChrome() {
    _hideTimer?.cancel();
    if (!mounted || _chromePinned) return;
    if (_chromeVisible) setState(() => _chromeVisible = false);
    ref.read(chromeVisibilityProvider.notifier).hide();
  }

  void _toggleChrome() {
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
      });
      ref.read(chromeVisibilityProvider.notifier).hide();
    } else {
      setState(() {
        _chromeVisible = true;
        _chromePinned = true;
      });
      ref.read(chromeVisibilityProvider.notifier).show();
    }
  }

  void _touchChrome() {
    if (!_chromePinned && _chromeVisible) _showChrome();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredEventsProvider);
    final categories = ref.watch(eventCategoriesProvider);
    final likedCount = ref.watch(favoritedEventsProvider).value?.length ?? 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

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

              if (!_handoffApplied && _handoffEventId != null) {
                _handoffApplied = true;
                final target = events.indexWhere(
                  (event) => event.id == _handoffEventId,
                );
                if (target >= 0) {
                  _index = target;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _pages.hasClients) {
                      _pages.jumpToPage(target);
                    }
                  });
                }
              }

              return PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                itemCount: events.length + 1,
                onPageChanged: (index) {
                  AppHaptics.selection();
                  setState(() => _index = index);
                  _touchChrome();
                },
                itemBuilder: (context, index) {
                  if (index == events.length) {
                    return PromoteCTACard(
                      onPromote: () =>
                          context.push(AppPaths.clientAdvertise),
                    );
                  }

                  final event = events[index];
                  return _EventPage(
                    event: event,
                    active: index == _index,
                    shouldLoadVideo: (index - _index).abs() <= 1,
                    chromeVisible: _chromeVisible,
                    likedCount: likedCount,
                    initialPosition: event.id == _handoffEventId
                        ? _handoffPosition
                        : null,
                    initialController: event.id == _handoffEventId
                        ? _handoffController
                        : null,
                    onToggleChrome: _toggleChrome,
                    onChromeInteraction: _touchChrome,
                    onOpenLikes: () {
                      _touchChrome();
                      context.push(AppPaths.exploreEventsLikes);
                    },
                    onOpen: () {
                      _touchChrome();
                      context.push(AppPaths.exploreEvent(event.id));
                    },
                  );
                },
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: AnimatedSlide(
                offset: _chromeVisible ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GlassIcon(
                            icon: Icons.arrow_back_rounded,
                            onTap: () {
                              ref
                                  .read(chromeVisibilityProvider.notifier)
                                  .show();
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(AppPaths.clientDashboard);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: categories.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 7),
                                itemBuilder: (context, i) {
                                  final category = categories[i];
                                  return _CategoryChip(
                                    category: category,
                                    active: _category == category.key,
                                    onTap: () {
                                      AppHaptics.light();
                                      setState(() {
                                        _category = category.key;
                                        _index = 0;
                                      });
                                      ref
                                          .read(
                                            selectedCategoryProvider.notifier,
                                          )
                                          .setCategory(category.key);
                                      if (_pages.hasClients) {
                                        _pages.jumpToPage(0);
                                      }
                                      _touchChrome();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: safeBottom + 18,
            child: _GlassIcon(
              icon: _chromeVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onTap: _togglePin,
              size: 38,
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
    required this.likedCount,
    required this.onToggleChrome,
    required this.onChromeInteraction,
    required this.onOpenLikes,
    required this.onOpen,
    this.initialPosition,
    this.initialController,
  });

  final Event event;
  final bool active;
  final bool shouldLoadVideo;
  final bool chromeVisible;
  final int likedCount;
  final VoidCallback onToggleChrome;
  final VoidCallback onChromeInteraction;
  final VoidCallback onOpenLikes;
  final VoidCallback onOpen;
  final Duration? initialPosition;
  final VideoPlayerController? initialController;

  @override
  ConsumerState<_EventPage> createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<_EventPage> {
  VideoPlayerController? _player;
  bool? _favoritedOverride;
  bool _busy = false;
  bool _initialApplied = false;

  Event get event => widget.event;
  bool get _hasVideo => (event.videoUrl ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final transferred = widget.initialController;
    if (transferred != null && transferred.value.isInitialized) {
      _player = transferred;
      _initialApplied = true;
      unawaited(_adoptTransferredVideo(transferred));
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
      unawaited(player.play());
    } else {
      unawaited(player.pause());
    }
  }

  Future<void> _adoptTransferredVideo(VideoPlayerController player) async {
    try {
      await player.setLooping(true);
      await player.setVolume(ref.read(deckSoundOnProvider) ? 1 : 0);
      if (widget.active) await player.play();
      if (mounted && identical(_player, player)) setState(() {});
    } catch (_) {
      if (!mounted || !identical(_player, player)) return;
      try {
        await player.dispose();
      } catch (_) {}
      _player = null;
      if (widget.shouldLoadVideo && _hasVideo) unawaited(_bindVideo());
    }
  }

  Future<void> _bindVideo() async {
    final url = event.videoUrl;
    if (url == null || url.trim().isEmpty) return;

    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = next;
    try {
      await next.initialize();
      await next.setLooping(true);

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

      await next.setVolume(ref.read(deckSoundOnProvider) ? 1 : 0);
      if (widget.active) await next.play();
      if (mounted && identical(_player, next)) setState(() {});
    } catch (_) {
      try {
        await next.dispose();
      } catch (_) {}
      if (identical(_player, next)) _player = null;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_busy) return;
    widget.onChromeInteraction();

    final current = _favoritedOverride ??
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
    await Clipboard.setData(
      ClipboardData(
        text: 'Check out ${event.title} on Swipess! ${event.shareUrl}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event link copied')),
    );
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
    final favorited = _favoritedOverride ??
        (ref.watch(eventFavoriteProvider(event.id)).value ?? false);
    final soundOn = ref.watch(deckSoundOnProvider);

    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      _player?.setVolume(on ? 1 : 0);
      if (on && widget.active) _player?.play();
    });

    final player = _player;
    final ready = player != null && player.value.isInitialized;
    final image = event.gallery.isNotEmpty
        ? event.gallery.first
        : (event.imageUrl ?? '');
    final bottom = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggleChrome,
      onDoubleTap: _toggleFavorite,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            AnimatedScale(
              scale: widget.chromeVisible ? 1.0 : 1.06,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: player.value.size.width,
                  height: player.value.size.height,
                  child: VideoPlayer(player),
                ),
              ),
            )
          else if (image.isNotEmpty)
            AnimatedScale(
              scale: widget.chromeVisible ? 1.0 : 1.06,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: Image.network(
                image,
                fit: BoxFit.cover,
                cacheWidth: (MediaQuery.sizeOf(context).width * 2)
                    .round()
                    .clamp(640, 1800),
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF16161C)),
              ),
            )
          else
            const ColoredBox(color: Color(0xFF16161C)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x22000000),
                  Colors.transparent,
                  Color(0xB0000000),
                ],
                stops: [0, .55, 1],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: bottom + 105,
            child: IgnorePointer(
              ignoring: !widget.chromeVisible,
              child: AnimatedSlide(
                offset: widget.chromeVisible
                    ? Offset.zero
                    : const Offset(1, 0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: widget.chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    children: [
                      _HeartLibraryButton(
                        count: widget.likedCount,
                        onTap: widget.onOpenLikes,
                      ),
                      const SizedBox(height: 10),
                      _HeartButton(
                        active: favorited,
                        onTap: _toggleFavorite,
                      ),
                      const SizedBox(height: 10),
                      EventMuteButton(
                        soundOn: soundOn,
                        onToggle: () {
                          widget.onChromeInteraction();
                          ref
                              .read(deckSoundOnProvider.notifier)
                              .setSoundOn(!soundOn);
                        },
                      ),
                      const SizedBox(height: 10),
                      _RailButton(
                        icon: Icons.info_outline_rounded,
                        onTap: widget.onOpen,
                      ),
                      const SizedBox(height: 6),
                      _RailButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        onTap: _whatsApp,
                      ),
                      const SizedBox(height: 6),
                      _RailButton(
                        icon: Icons.share_rounded,
                        onTap: _share,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 82,
            bottom: bottom + 26,
            child: IgnorePointer(
              ignoring: !widget.chromeVisible,
              child: AnimatedSlide(
                offset: widget.chromeVisible
                    ? Offset.zero
                    : const Offset(0, 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: widget.chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaPill(label: event.category.toUpperCase()),
                          if (event.isFree) const _MetaPill(label: 'FREE'),
                          if (_hasVideo) const _MetaPill(label: 'VIDEO'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        event.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.04,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 12),
                          ],
                        ),
                      ),
                      if ((event.organizerName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          'by ${event.organizerName}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if ((event.promoText ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          event.promoText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
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
    );
  }
}

class _HeartLibraryButton extends StatelessWidget {
  const _HeartLibraryButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFFF3040),
              size: 31,
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFF3040),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: active ? 1.08 : 1,
            child: Icon(
              active
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: active ? const Color(0xFFFF3040) : Colors.white,
              size: 31,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    required this.onTap,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

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
            size: 21,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
      child: SizedBox(
        width: 50,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFFFF3040), Color(0xFFEB4898)],
                      )
                    : null,
                color: active ? null : Colors.black54,
              ),
              child: ClipOval(
                child: category.image.startsWith('assets/')
                    ? Image.asset(
                        category.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(category.icon),
                      )
                    : Image.network(
                        category.image,
                        fit: BoxFit.cover,
                        cacheWidth: 140,
                        errorBuilder: (_, _, _) => Icon(category.icon),
                      ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 8.5,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandPrimary.withAlpha(55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
