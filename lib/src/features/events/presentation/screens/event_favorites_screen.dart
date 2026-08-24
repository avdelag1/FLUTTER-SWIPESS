import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// The user's persistent event likes.
///
/// This page always refreshes on entry so likes changed from the feed or an
/// event detail screen cannot remain stale in Riverpod's provider cache.
class EventFavoritesScreen extends ConsumerStatefulWidget {
  const EventFavoritesScreen({super.key});

  @override
  ConsumerState<EventFavoritesScreen> createState() =>
      _EventFavoritesScreenState();
}

class _EventFavoritesScreenState extends ConsumerState<EventFavoritesScreen> {
  final _search = TextEditingController();
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(favoritedEventsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoritedEventsProvider);

    return NeoNaiveScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  CapBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIKED EVENTS',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          'The experiences you want to remember',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(175),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh likes',
                    onPressed: () =>
                        ref.read(favoritedEventsProvider.notifier).refresh(),
                    icon: const Icon(Icons.sync_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Colors.white.withAlpha(180),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search your likes...',
                          hintStyle: TextStyle(
                            color: Colors.white.withAlpha(115),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in const [
                    ('all', 'All'),
                    ('Nightlife', 'Nightlife'),
                    ('Music', 'Music'),
                    ('Food', 'Food'),
                    ('Sports', 'Sports'),
                    ('Art', 'Art'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: NeoNaiveChip(
                        label: c.$2,
                        selected: _category == c.$1,
                        onSelected: () => setState(() => _category = c.$1),
                        selectedColor: const Color(0xFF3B82F6),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
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
                        ref.read(favoritedEventsProvider.notifier).refresh(),
                    child: const Text('Could not load likes — retry'),
                  ),
                ),
                data: (events) {
                  final q = _search.text.trim().toLowerCase();
                  final filtered = events.where((e) {
                    final catOk =
                        _category == 'all' ||
                        e.category.toLowerCase() == _category.toLowerCase();
                    final qOk =
                        q.isEmpty ||
                        e.title.toLowerCase().contains(q) ||
                        (e.location?.toLowerCase().contains(q) ?? false) ||
                        e.category.toLowerCase().contains(q);
                    return catOk && qOk;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withAlpha(24),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.thumb_up_alt_outlined,
                                color: Color(0xFF60A5FA),
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              q.isEmpty && _category == 'all'
                                  ? 'Like an event and it will stay here for you.'
                                  : 'No liked events match this search.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(190),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.explore_outlined),
                              label: const Text('Browse events'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = filtered[index];
                      return _LikedEventCard(
                        event: event,
                        onOpen: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(
                                event: event,
                                siblings: filtered,
                              ),
                            ),
                          );
                          if (mounted) {
                            ref
                                .read(favoritedEventsProvider.notifier)
                                .refresh();
                          }
                        },
                        onRemove: () {
                          AppHaptics.medium();
                          ref
                              .read(favoritedEventsProvider.notifier)
                              .remove(event.id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikedEventCard extends StatelessWidget {
  const _LikedEventCard({
    required this.event,
    required this.onOpen,
    required this.onRemove,
  });

  final Event event;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final date = event.eventDate == null
        ? 'TBA'
        : DateFormat('MMM d · h:mm a').format(event.eventDate!.toLocal());

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final mediaWidth = compact ? 112.0 : 176.0;
        final cardHeight = compact ? 136.0 : 152.0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              height: cardHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF15171D),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(65),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Media is intentionally a completely isolated paint zone.
                    // ClipRect prevents Flutter web video/image paint from ever
                    // escaping underneath the event copy.
                    SizedBox(
                      width: mediaWidth,
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _SavedEventPreview(event: event),
                            if (event.videoUrl?.trim().isNotEmpty == true)
                              Positioned(
                                left: 12,
                                bottom: 12,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(150),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withAlpha(45),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      color: Colors.white.withAlpha(18),
                    ),
                    SizedBox(width: compact ? 14 : 20),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 13 : 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.category.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF60A5FA),
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: compact ? 15 : 17,
                                height: 1.15,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(190),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              event.location ?? event.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(125),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 16),
                    Padding(
                      padding: EdgeInsets.only(right: compact ? 10 : 14),
                      child: Center(
                        child: Tooltip(
                          message: 'Remove from likes',
                          child: InkWell(
                            onTap: onRemove,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: compact ? 44 : 50,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withAlpha(24),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF60A5FA).withAlpha(28),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.thumb_up_alt_rounded,
                                    color: Color(0xFF60A5FA),
                                    size: 20,
                                  ),
                                  if (!compact) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'LIKED',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF93C5FD),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
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

class _SavedEventPreview extends StatefulWidget {
  const _SavedEventPreview({required this.event});

  final Event event;

  @override
  State<_SavedEventPreview> createState() => _SavedEventPreviewState();
}

class _SavedEventPreviewState extends State<_SavedEventPreview> {
  VideoPlayerController? _video;

  String? get _still {
    final image = widget.event.imageUrl?.trim();
    if (image != null && image.isNotEmpty) return image;
    for (final item in widget.event.gallery) {
      final value = item.trim();
      if (value.isNotEmpty && !_looksLikeVideo(value)) return value;
    }
    return null;
  }

  bool _looksLikeVideo(String value) {
    final l = value.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.mov') ||
        l.contains('.webm') ||
        l.contains('/videos/');
  }

  @override
  void initState() {
    super.initState();
    if (_still == null && widget.event.videoUrl?.trim().isNotEmpty == true) {
      unawaited(_loadVideoFrame());
    }
  }

  Future<void> _loadVideoFrame() async {
    final url = widget.event.videoUrl?.trim();
    if (url == null || url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      final duration = controller.value.duration;
      if (duration > const Duration(milliseconds: 500)) {
        await controller.seekTo(const Duration(milliseconds: 350));
      }
      await controller.pause();
      if (mounted) setState(() {});
    } catch (_) {
      await controller.dispose();
      if (identical(_video, controller)) _video = null;
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    if (still != null) {
      return SizedBox.expand(
        child: Image.network(
          still,
          fit: BoxFit.cover,
          cacheWidth: 520,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }

    final player = _video;
    if (player != null && player.value.isInitialized) {
      final size = player.value.size;
      return SizedBox.expand(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(player),
            ),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF22304A), Color(0xFF111318)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.celebration_rounded,
            color: Color(0xFF60A5FA),
            size: 32,
          ),
        ),
      ),
    );
  }
}
