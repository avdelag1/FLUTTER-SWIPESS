import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/bulk_selection_bar.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EventFavoritesScreen extends ConsumerStatefulWidget {
  const EventFavoritesScreen({super.key});

  @override
  ConsumerState<EventFavoritesScreen> createState() =>
      _EventFavoritesScreenState();
}

class _EventFavoritesScreenState extends ConsumerState<EventFavoritesScreen> {
  static const _accent = Color(0xFF4C8DFF);
  final _search = TextEditingController();
  final Set<String> _selected = <String>{};
  String _category = 'all';
  bool _selecting = false;
  bool _deleting = false;

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

  void _beginSelection([String? id]) {
    AppHaptics.selection();
    setState(() {
      _selecting = true;
      if (id != null) _selected.add(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggle(String id) {
    AppHaptics.selection();
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  List<Event> _filtered(List<Event> events) {
    final query = _search.text.trim().toLowerCase();
    return events.where((event) {
      final categoryOk = _category == 'all' ||
          event.category.toLowerCase() == _category.toLowerCase();
      final queryOk = query.isEmpty ||
          event.title.toLowerCase().contains(query) ||
          (event.location?.toLowerCase().contains(query) ?? false) ||
          event.category.toLowerCase().contains(query);
      return categoryOk && queryOk;
    }).toList();
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _deleting) return;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'Remove liked event?' : 'Remove $count liked events?'),
        content: const Text('The selected events will be removed from your Likes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final notifier = ref.read(favoritedEventsProvider.notifier);
      for (final id in _selected.toList()) {
        await notifier.remove(id);
      }
      if (mounted) _cancelSelection();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove selected events')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 7),
              child: Row(
                children: [
                  CapBackButton(
                    onTap: _selecting ? _cancelSelection : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selecting ? 'SELECT EVENTS' : 'LIKED EVENTS',
                          style: AppTheme.displayItalic.copyWith(fontSize: 21),
                        ),
                        if (!_selecting)
                          Text(
                            'Your saved experiences',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withAlpha(155),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_selecting)
                    IconButton(
                      tooltip: 'Select events',
                      onPressed: () => _beginSelection(),
                      icon: const Icon(
                        Icons.checklist_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  if (!_selecting)
                    IconButton(
                      tooltip: 'Refresh likes',
                      onPressed: () =>
                          ref.read(favoritedEventsProvider.notifier).refresh(),
                      icon: const Icon(
                        Icons.sync_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            async.maybeWhen(
              data: (events) {
                final visible = _filtered(events);
                _selected.removeWhere(
                  (id) => !events.any((event) => event.id == id),
                );
                if (!_selecting) return const SizedBox.shrink();
                final visibleIds = visible.map((event) => event.id).toList();
                return BulkSelectionBar(
                  selectedCount: _selected.length,
                  totalCount: visibleIds.length,
                  busy: _deleting,
                  accent: _accent,
                  deleteLabel: 'Remove',
                  onCancel: _cancelSelection,
                  onSelectAll: () {
                    setState(() {
                      final all = visibleIds.isNotEmpty &&
                          visibleIds.every(_selected.contains);
                      if (all) {
                        _selected.removeAll(visibleIds);
                      } else {
                        _selected.addAll(visibleIds);
                      }
                    });
                  },
                  onDelete: _deleteSelected,
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            if (!_selecting) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(18)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: Colors.white.withAlpha(155),
                        size: 17,
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
                            hintText: 'Search liked events',
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha(105),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final category in const [
                      ('all', 'All'),
                      ('Nightlife', 'Nightlife'),
                      ('Music', 'Music'),
                      ('Food', 'Food'),
                      ('Sports', 'Sports'),
                      ('Art', 'Art'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: _CategoryChip(
                          label: category.$2,
                          selected: _category == category.$1,
                          onTap: () => setState(() => _category = category.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
            ],
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: _accent,
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
                  final filtered = _filtered(events);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          events.isEmpty
                              ? 'Events you like will appear here.'
                              : 'No liked events match this search.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(170),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = filtered[index];
                      return _LikedEventCard(
                        event: event,
                        selecting: _selecting,
                        selected: _selected.contains(event.id),
                        onSelect: () {
                          if (_selecting) {
                            _toggle(event.id);
                          } else {
                            _beginSelection(event.id);
                          }
                        },
                        onOpen: () async {
                          if (_selecting) {
                            _toggle(event.id);
                            return;
                          }
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
                        onRemove: () => ref
                            .read(favoritedEventsProvider.notifier)
                            .remove(event.id),
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
    required this.selecting,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onRemove,
  });

  final Event event;
  final bool selecting;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  String? get _image {
    final primary = event.imageUrl?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    for (final image in event.gallery) {
      if (image.trim().isNotEmpty) return image.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final date = event.eventDate == null
        ? 'TBA'
        : DateFormat('MMM d · h:mm a').format(event.eventDate!.toLocal());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selecting ? onSelect : onOpen,
        onLongPress: onSelect,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 132,
          decoration: BoxDecoration(
            color: const Color(0xFF15171D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? _EventFavoritesScreenState._accent.withAlpha(170)
                  : Colors.white.withAlpha(14),
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // The media and copy are separate layout/paint zones. No stack
              // or video surface can paint beneath the event title.
              SizedBox(
                width: 126,
                height: double.infinity,
                child: ClipRect(
                  child: _image == null
                      ? const ColoredBox(
                          color: Color(0xFF20242C),
                          child: Icon(
                            Icons.celebration_outlined,
                            color: Colors.white30,
                            size: 34,
                          ),
                        )
                      : CachedNetworkImage(
  imageUrl: _image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFF20242C),
                          ),
                        ),
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 14),
                color: Colors.white.withAlpha(18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: _EventFavoritesScreenState._accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withAlpha(180),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        event.location ?? 'Location TBA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withAlpha(115),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Padding(
                padding: const EdgeInsets.only(right: 11),
                child: selecting
                    ? SelectionBadge(
                        selected: selected,
                        accent: _EventFavoritesScreenState._accent,
                      )
                    : IconButton(
                        tooltip: 'Remove from likes',
                        onPressed: onRemove,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              _EventFavoritesScreenState._accent.withAlpha(22),
                        ),
                        icon: const Icon(
                          Icons.favorite_rounded,
                          color: _EventFavoritesScreenState._accent,
                          size: 20,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _EventFavoritesScreenState._accent.withAlpha(28)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _EventFavoritesScreenState._accent.withAlpha(115)
                : Colors.white.withAlpha(18),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected
                ? _EventFavoritesScreenState._accent
                : Colors.white.withAlpha(210),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
