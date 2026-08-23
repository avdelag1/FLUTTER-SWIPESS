import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';

/// Capacitor EventosLikes — saved / favorited events.
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  CapBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAVED EVENTS',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          'Your curated social calendar',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
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
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
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
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search title or location...',
                          hintStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
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
                        selectedColor: AppTheme.brandPrimary,
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
                    child: const Text('Could not load — retry'),
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
                        (e.location?.toLowerCase().contains(q) ?? false);
                    return catOk && qOk;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_border_rounded,
                              color: Colors.white24,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your favorite experiences are waiting. Start browsing events to curate your calendar.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Browse events'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = filtered[index];
                      return _FavCard(
                        event: event,
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(
                                event: event,
                                siblings: filtered,
                              ),
                            ),
                          );
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

class _FavCard extends StatelessWidget {
  const _FavCard({
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 118,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: event.imageUrl == null
                    ? const ColoredBox(color: Color(0xFF16161C))
                    : Image.network(event.imageUrl!, fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        date,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.location ?? event.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
