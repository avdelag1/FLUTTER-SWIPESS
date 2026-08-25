import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/bulk_selection_bar.dart';
import 'package:flutter_swipes/src/core/widgets/cap_empty_state.dart';
import 'package:flutter_swipes/src/features/likes/domain/profile_like.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/who_liked_you_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/widgets/premium_liked_card.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

const _likesAccent = Color(0xFF4C8DFF);
const _likesAccent2 = Color(0xFF7767FF);

/// Compact saved-content manager for listings and people.
class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen> {
  int _segment = 0;
  String _category = 'all';
  String _sort = 'newest';
  final _search = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _selecting = false;
  bool _deleting = false;

  static const _listingCats = [
    ('all', 'All', Icons.favorite_rounded),
    ('property', 'Properties', Icons.home_rounded),
    ('motorcycle', 'Motorcycles', Icons.two_wheeler_rounded),
    ('bicycle', 'Bicycles', Icons.pedal_bike_rounded),
    ('worker', 'Workers', Icons.work_rounded),
    ('roommate', 'Roommates', Icons.people_rounded),
  ];

  static const _peopleCats = [
    ('all', 'All', Icons.people_alt_rounded),
    ('renter', 'Renters', Icons.key_rounded),
    ('worker', 'Workers', Icons.work_rounded),
    ('buyer', 'Buyers', Icons.sell_rounded),
  ];

  static const _sorts = [
    ('newest', 'Newest'),
    ('oldest', 'Oldest'),
    ('price_up', 'Price ↑'),
    ('price_down', 'Price ↓'),
    ('az', 'A → Z'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setSegment(int value) {
    if (_segment == value) return;
    AppHaptics.selection();
    setState(() {
      _segment = value;
      _category = 'all';
      _selecting = false;
      _selected.clear();
    });
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

  Future<void> _openChat({
    required String userId,
    required String name,
    String? avatar,
    String? listingId,
  }) async {
    if (userId.isEmpty) return;
    AppHaptics.medium();
    final convoId = await SwipeRepository().startConversation(
      ownerId: userId,
      listingId: listingId,
    );
    if (!mounted || convoId == null) return;
    await showChatPopup(
      context,
      isNewConversation: true,
      conversation: ChatConversation(
        id: convoId,
        otherUserId: userId,
        name: name,
        lastMessage: '',
        timestamp: 'now',
        avatarUrl: avatar,
      ),
    );
  }

  Future<bool> _confirmRemove(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'Remove saved item?' : 'Remove $count saved items?'),
        content: const Text('The selected items will be removed from your Likes.'),
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
    return ok ?? false;
  }

  Future<void> _deleteBulk() async {
    if (_selected.isEmpty || _deleting) return;
    if (!await _confirmRemove(_selected.length)) return;
    final ids = _selected.toList();
    setState(() => _deleting = true);
    try {
      if (_segment == 0) {
        final notifier = ref.read(likedListingsProvider.notifier);
        for (final id in ids) {
          await notifier.remove(id);
        }
      } else {
        final notifier = ref.read(likedPeopleProvider.notifier);
        for (final id in ids) {
          await notifier.remove(id);
        }
      }
      if (mounted) _cancelSelection();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove selected items')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(likedListingsProvider);
    final peopleAsync = ref.watch(likedPeopleProvider);
    final ink = MatteSurface.ink(context);

    return ColoredBox(
      color: MatteSurface.canvas(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: _Seg(
                    label: 'Listings',
                    selected: _segment == 0,
                    onTap: () => _setSegment(0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Seg(
                    label: 'People',
                    selected: _segment == 1,
                    onTap: () => _setSegment(1),
                  ),
                ),
                const SizedBox(width: 8),
                _RoundAction(
                  tooltip: _selecting ? 'Cancel selection' : 'Select saved items',
                  icon: _selecting ? Icons.close_rounded : Icons.checklist_rounded,
                  onTap: _selecting ? _cancelSelection : () => _beginSelection(),
                ),
              ],
            ),
          ),
          if (_selecting)
            _segment == 0
                ? listingsAsync.maybeWhen(
                    data: (items) {
                      final visible = _filterListings(items);
                      return _bulkBar(visible.map((item) => item.id).toList());
                    },
                    orElse: () => const SizedBox.shrink(),
                  )
                : peopleAsync.maybeWhen(
                    data: (items) {
                      final visible = _filterPeople(items);
                      return _bulkBar(
                        visible.map((item) => item.userId).toList(),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
          if (!_selecting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  if (_segment == 1)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Saved people',
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WhoLikedYouScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.favorite_border_rounded,
                            size: 14,
                          ),
                          label: const Text('Liked me'),
                          style: TextButton.styleFrom(
                            foregroundColor: _likesAccent,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  _HChips(
                    items: _segment == 0 ? _listingCats : _peopleCats,
                    selected: _category,
                    onTap: (id) => setState(() => _category = id),
                    trailing: _segment == 0
                        ? _RoundAction(
                            tooltip: 'Refresh',
                            icon: Icons.sync_rounded,
                            onTap: () => ref
                                .read(likedListingsProvider.notifier)
                                .refresh(),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _SearchField(
                    controller: _search,
                    hint: _segment == 0
                        ? 'Search saved listings'
                        : 'Search saved people',
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_segment == 0) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final sort in _sorts)
                            _SortChip(
                              label: sort.$2,
                              selected: _sort == sort.$1,
                              onTap: () => setState(() => _sort = sort.$1),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _segment == 0
                ? listingsAsync.when(
                    loading: () => const _Loading(),
                    error: (_, _) => _Retry(
                      onTap: () =>
                          ref.read(likedListingsProvider.notifier).refresh(),
                    ),
                    data: (items) => _buildListings(_filterListings(items)),
                  )
                : peopleAsync.when(
                    loading: () => const _Loading(),
                    error: (_, _) => _Retry(
                      onTap: () =>
                          ref.read(likedPeopleProvider.notifier).refresh(),
                    ),
                    data: (items) => _buildPeople(_filterPeople(items)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bulkBar(List<String> visibleIds) {
    _selected.removeWhere((id) => !visibleIds.contains(id));
    return BulkSelectionBar(
      selectedCount: _selected.length,
      totalCount: visibleIds.length,
      busy: _deleting,
      accent: _likesAccent,
      deleteLabel: 'Remove',
      onCancel: _cancelSelection,
      onSelectAll: () {
        setState(() {
          final all = visibleIds.isNotEmpty && visibleIds.every(_selected.contains);
          if (all) {
            _selected.removeAll(visibleIds);
          } else {
            _selected.addAll(visibleIds);
          }
        });
      },
      onDelete: _deleteBulk,
    );
  }

  List<Listing> _filterListings(List<Listing> items) {
    final q = _search.text.trim().toLowerCase();
    final filtered = items.where((listing) {
      if (_category != 'all' && listing.category != _category) return false;
      if (q.isEmpty) return true;
      return (listing.title ?? '').toLowerCase().contains(q) ||
          (listing.city ?? '').toLowerCase().contains(q) ||
          (listing.description ?? '').toLowerCase().contains(q);
    }).toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case 'oldest':
          return (a.createdAt ?? DateTime(0)).compareTo(
            b.createdAt ?? DateTime(0),
          );
        case 'price_up':
          return (a.price ?? 0).compareTo(b.price ?? 0);
        case 'price_down':
          return (b.price ?? 0).compareTo(a.price ?? 0);
        case 'az':
          return (a.title ?? '').compareTo(b.title ?? '');
        default:
          return (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          );
      }
    });
    return filtered;
  }

  List<ProfileLike> _filterPeople(List<ProfileLike> items) {
    final q = _search.text.trim().toLowerCase();
    return items.where((person) {
      if (_category != 'all') {
        final occupation = (person.occupation ?? '').toLowerCase();
        if (!occupation.contains(_category)) return false;
      }
      if (q.isEmpty) return true;
      return person.name.toLowerCase().contains(q) ||
          (person.occupation ?? '').toLowerCase().contains(q) ||
          (person.bio ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Widget _buildListings(List<Listing> items) {
    if (items.isEmpty) {
      return Center(
        child: CapEmptyState(
          variant: CapEmptyVariant.likes,
          icon: Icons.favorite_border_rounded,
          title: 'Nothing saved yet.',
          description: 'Listings you save will appear here.',
          actionLabel: 'EXPLORE',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 390,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .80,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final listing = items[index];
        return PremiumLikedCard(
          imageUrl: listing.primaryImage,
          title: listing.title ?? 'Listing',
          subtitle:
              listing.city ?? listing.location ?? listing.neighborhood ?? '',
          category: listing.category ?? listing.propertyType ?? 'Listing',
          description: listing.description,
          bedsLabel: listing.beds == null ? null : '${listing.beds}',
          priceLabel: listing.price == null
              ? null
              : '\$${listing.price!.toStringAsFixed(0)}${listing.pricingUnit != null ? '/${listing.pricingUnit}' : '/mo'}',
          selectionMode: _selecting,
          selected: _selected.contains(listing.id),
          onSelect: () => _selecting
              ? _toggle(listing.id)
              : _beginSelection(listing.id),
          onMessage: () => _openChat(
            userId: listing.ownerId ?? '',
            name: listing.title ?? 'Owner',
            avatar: listing.primaryImage,
            listingId: listing.id,
          ),
          onView: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ListingDetailScreen(listingData: listing),
            ),
          ),
          onRemove: () async {
            if (!await _confirmRemove(1)) return;
            await ref.read(likedListingsProvider.notifier).remove(listing.id);
          },
        );
      },
    );
  }

  Widget _buildPeople(List<ProfileLike> items) {
    if (items.isEmpty) {
      return Center(
        child: CapEmptyState(
          variant: CapEmptyVariant.likes,
          icon: Icons.favorite_border_rounded,
          title: 'Nothing saved yet.',
          description: 'People you save will appear here.',
          actionLabel: 'EXPLORE',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final person = items[index];
        return PremiumLikedCard(
          isProfile: true,
          imageUrl: person.primaryImage,
          title: person.name,
          subtitle: [
            if (person.occupation != null) person.occupation!,
            if (person.age != null) '${person.age} years old',
          ].join(' · '),
          category: 'Profile',
          description: person.bio,
          selectionMode: _selecting,
          selected: _selected.contains(person.userId),
          onSelect: () => _selecting
              ? _toggle(person.userId)
              : _beginSelection(person.userId),
          onMessage: () => _openChat(
            userId: person.userId,
            name: person.name,
            avatar: person.primaryImage,
          ),
          onView: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileDetailScreen(userId: person.userId),
            ),
          ),
          onRemove: () async {
            if (!await _confirmRemove(1)) return;
            await ref.read(likedPeopleProvider.notifier).remove(person.userId);
          },
        );
      },
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_likesAccent, _likesAccent2])
              : null,
          color: selected ? null : MatteSurface.well(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : MatteSurface.hairline(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : MatteSurface.ink(context),
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _HChips extends StatelessWidget {
  const _HChips({
    required this.items,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final List<(String, String, IconData)> items;
  final String selected;
  final ValueChanged<String> onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: InkWell(
                onTap: () => onTap(item.$1),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: selected == item.$1
                        ? _likesAccent.withAlpha(28)
                        : MatteSurface.well(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected == item.$1
                          ? _likesAccent.withAlpha(110)
                          : MatteSurface.hairline(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.$3,
                        size: 12,
                        color: selected == item.$1
                            ? _likesAccent
                            : MatteSurface.ink(context),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.$2,
                        style: GoogleFonts.plusJakartaSans(
                          color: selected == item.$1
                              ? _likesAccent
                              : MatteSurface.ink(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? _likesAccent.withAlpha(24)
                : MatteSurface.well(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? _likesAccent.withAlpha(95)
                  : MatteSurface.hairline(context),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: selected ? _likesAccent : MatteSurface.ink(context),
              fontWeight: FontWeight.w800,
              fontSize: 9.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: MatteSurface.well(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: muted, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: MatteSurface.ink(context), fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: muted, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MatteSurface.well(context),
            shape: BoxShape.circle,
            border: Border.all(color: MatteSurface.hairline(context)),
          ),
          child: Icon(icon, color: MatteSurface.muted(context), size: 17),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: _likesAccent, strokeWidth: 2),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: const Text('Could not load — retry'),
      ),
    );
  }
}
