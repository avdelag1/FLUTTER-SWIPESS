import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/event_connect.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/event_mute_button.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/promote_cta_card.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// Cap EventosFeed — Instagram-stories vertical snap deck with preload.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _pages = PageController();
  int _index = 0;
  String _category = 'All';

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredEventsProvider);

    return ColoredBox(
      color: Colors.black,
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.read(eventsListProvider.notifier).refresh(),
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
                    style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _category = 'All');
                      ref.read(selectedCategoryProvider.notifier).setCategory('All');
                    },
                    child: const Text('Show all'),
                  ),
                ],
              ),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                allowImplicitScrolling: true,
                // Cap: one extra virtual row — PromoteCTACard at end of feed.
                itemCount: events.length + 1,
                onPageChanged: (i) {
                  AppHaptics.selection();
                  setState(() => _index = i);
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
                    onOpen: () {
                      context.push(AppPaths.exploreEvent(event.id));
                    },
                  );
                },
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                right: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopIcon(
                      icon: Icons.arrow_back_rounded,
                      color: Colors.white,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppPaths.clientDashboard);
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 62,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final c in ref.watch(eventCategoriesProvider))
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _EventCategoryRing(
                                  category: c,
                                  active: _category == c.key,
                                  onTap: () {
                                    AppHaptics.light();
                                    setState(() {
                                      _category = c.key;
                                      _index = 0;
                                    });
                                    ref
                                        .read(selectedCategoryProvider.notifier)
                                        .setCategory(c.key);
                                    if (_pages.hasClients) {
                                      _pages.jumpToPage(0);
                                    }
                                  },
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _EventCategoryRing(
                                category: const EventFeedCategory(
                                  key: 'likes',
                                  label: 'My Likes',
                                  icon: Icons.favorite_rounded,
                                  image: 'assets/filters/events.jpg',
                                  color: Color(0xFFEC4899),
                                ),
                                active: false,
                                onTap: () {
                                  AppHaptics.light();
                                  context.push(AppPaths.exploreEventsLikes);
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
              // Progress ticks like stories
              Positioned(
                top: MediaQuery.paddingOf(context).top + 78,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    for (var i = 0; i < events.length.clamp(0, 12); i++)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: i <= _index
                                ? Colors.white
                                : Colors.white.withAlpha(60),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
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
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(150),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

/// Cap `EventCategoryCircle` — gradient ring when active + photo + label.
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
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
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
                color: active ? null : Colors.white.withAlpha(40),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: const Color(0xFFEB4898).withAlpha(70),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A0A0B), width: 1.5),
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
                          color: Colors.white70,
                        ),
                      )
                    : Image.network(
                        category.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          category.icon,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: active ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.2,
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
    required this.onOpen,
  });

  final Event event;
  final bool active;
  final bool shouldLoadVideo;
  final List<Event> siblings;
  final VoidCallback onOpen;

  @override
  ConsumerState<_EventStoryPage> createState() => _EventStoryPageState();
}

class _EventStoryPageState extends ConsumerState<_EventStoryPage> {
  VideoPlayerController? _player;
  bool? _favoritedOverride;
  bool _showChrome = true;

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
    final current = _favoritedOverride ??
        (ref.read(eventFavoriteProvider(event.id)).value ?? false);
    setState(() => _favoritedOverride = !current);
    AppHaptics.medium();
    try {
      await ref.read(eventRepositoryProvider).setFavorited(
            event.id,
            favorited: !current,
          );
      ref.invalidate(eventFavoriteProvider(event.id));
      ref.invalidate(favoritedEventsProvider);
    } catch (_) {
      setState(() => _favoritedOverride = current);
    }
  }

  Future<void> _share() async {
    AppHaptics.light();
    await Clipboard.setData(ClipboardData(
      text: 'Check out ${event.title} on Swipess! ${event.shareUrl}',
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event link copied')),
    );
  }

  Future<void> _whatsApp() async {
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
      onTap: () => setState(() => _showChrome = !_showChrome),
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
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0xCC000000),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),

          // Side action rail (Cap EventCard)
          if (_showChrome)
            Positioned(
              right: 12,
              bottom: bottom + 110,
              child: Column(
                children: [
                  _RailBtn(
                    icon: favorited
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: favorited ? const Color(0xFFF43F5E) : Colors.white,
                    onTap: _toggleFavorite,
                  ),
                  const SizedBox(height: 10),
                  EventMuteButton(
                    soundOn: ref.watch(deckSoundOnProvider),
                    onToggle: () {
                      final next = !ref.read(deckSoundOnProvider);
                      ref.read(deckSoundOnProvider.notifier).setSoundOn(next);
                      _player?.setVolume(next ? 1 : 0);
                      if (next) _player?.play();
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Column(
                      children: [
                        _RailBtn(
                          icon: Icons.info_outline_rounded,
                          size: 44,
                          onTap: widget.onOpen,
                        ),
                        _RailBtn(
                          icon: Icons.chat_rounded,
                          size: 44,
                          onTap: _whatsApp,
                        ),
                        _RailBtn(
                          icon: Icons.share_rounded,
                          size: 44,
                          onTap: _share,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_showChrome)
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
                        color: Colors.white70,
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
                    'Swipe up for next · tap for chrome · open for details',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RailBtn extends StatelessWidget {
  const _RailBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.size = 52,
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
          color: Colors.black.withAlpha(140),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: color, size: size > 48 ? 22 : 18),
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
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
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
