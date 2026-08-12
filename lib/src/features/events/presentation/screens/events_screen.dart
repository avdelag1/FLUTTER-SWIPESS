import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_detail_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/category_filter_chips.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredEvents = ref.watch(filteredEventsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppTheme.dashBg,
      child: RefreshIndicator(
        color: AppTheme.brandPrimary,
        onRefresh: () => ref.read(eventsListProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, top + 72, 20, 0),
                child: Column(
                  children: [
                    GlowSearchBar(
                      hint: 'Search events',
                      onChanged: (value) =>
                          ref.read(eventSearchProvider.notifier).set(value),
                    ),
                    const SizedBox(height: 14),
                    const CategoryFilterChips(),
                  ],
                ),
              ),
            ),
            ...filteredEvents.when(
              loading: () => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                ),
              ],
              error: (_, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.read(eventsListProvider.notifier).refresh(),
                      child: const Text('Could not load events — retry'),
                    ),
                  ),
                ),
              ],
              data: (events) {
                if (events.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No $selectedCategory events',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                        ),
                      ),
                    ),
                  ];
                }
                return [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = events[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(event: event),
                                ),
                              );
                            },
                            child: _EventTile(
                              imageUrl: event.imageUrl ?? '',
                              videoUrl: event.videoUrl,
                              label: event.title,
                              meta: event.price.isEmpty ? event.category : event.price,
                            ),
                          );
                        },
                        childCount: events.length,
                      ),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.imageUrl,
    required this.label,
    required this.meta,
    this.videoUrl,
  });

  final String imageUrl;
  final String? videoUrl;
  final String label;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoUrl != null && videoUrl!.trim().isNotEmpty)
            _LoopThumb(url: videoUrl!, poster: imageUrl)
          else if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF16161C)),
            )
          else
            const ColoredBox(color: Color(0xFF16161C)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

class _LoopThumb extends StatefulWidget {
  const _LoopThumb({required this.url, required this.poster});
  final String url;
  final String poster;

  @override
  State<_LoopThumb> createState() => _LoopThumbState();
}

class _LoopThumbState extends State<_LoopThumb> {
  VideoPlayerController? _player;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final player = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _player = player;
    try {
      await player.initialize();
      await player.setLooping(true);
      await player.setVolume(0);
      await player.play();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null || !player.value.isInitialized) {
      if (widget.poster.isEmpty) {
        return const ColoredBox(color: Color(0xFF16161C));
      }
      return Image.network(
        widget.poster,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF16161C)),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: player.value.size.width,
        height: player.value.size.height,
        child: VideoPlayer(player),
      ),
    );
  }
}
