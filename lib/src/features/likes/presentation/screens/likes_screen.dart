import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/cap_empty_state.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/who_liked_you_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/widgets/premium_liked_card.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `UnifiedLikes` + `ClientLikedProperties` + `LikedClients`.
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

  static const _gradient = LinearGradient(
    colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
  );

  static const _listingCats = [
    ('all', 'All Favorites', Icons.local_fire_department_rounded),
    ('property', 'Properties', Icons.home_rounded),
    ('motorcycle', 'Motorcycles', Icons.two_wheeler_rounded),
    ('bicycle', 'Bicycles', Icons.pedal_bike_rounded),
    ('worker', 'Workers', Icons.work_rounded),
    ('roommate', 'Roommates', Icons.people_rounded),
  ];

  static const _peopleCats = [
    ('all', 'All Talents', Icons.auto_awesome_rounded),
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

  Future<void> _openChat({
    required String userId,
    required String name,
    String? avatar,
    String? listingId,
  }) async {
    HapticFeedback.mediumImpact();
    final convoId = await SwipeRepository().startConversation(
      ownerId: userId,
      listingId: listingId,
    );
    if (!mounted || convoId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: ChatConversation(
            id: convoId,
            otherUserId: userId,
            name: name,
            lastMessage: '',
            timestamp: 'now',
            avatarUrl: avatar,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmRemove(String title, {required bool match}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          match ? 'Remove Match?' : 'Remove from likes?',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          match
              ? 'Are you sure you want to remove $title?'
              : 'Are you sure you want to remove "$title" from your likes?',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'REMOVE',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFE4007C),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final listingsAsync = ref.watch(likedListingsProvider);
    final peopleAsync = ref.watch(likedPeopleProvider);

    final ink = MatteSurface.ink(context);
    final well = MatteSurface.well(context);
    final hairline = MatteSurface.hairline(context);

    return ColoredBox(
      color: MatteSurface.canvas(context),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, top + 64, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: well,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: hairline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Seg(
                            label: 'Liked Listings',
                            selected: _segment == 0,
                            onTap: () => setState(() => _segment = 0),
                          ),
                        ),
                        Expanded(
                          child: _Seg(
                            label: 'Liked People',
                            selected: _segment == 1,
                            onTap: () => setState(() => _segment = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_segment == 1) ...[
                    Row(
                      children: [
                        Text(
                          'Your Talents',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WhoLikedYouScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Liked Me',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFE4007C),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _HChips(
                      items: _peopleCats,
                      selected: _category,
                      onTap: (id) => setState(() => _category = id),
                    ),
                    const SizedBox(height: 10),
                    _SearchField(
                      controller: _search,
                      hint: 'Search talents...',
                      onChanged: (_) => setState(() {}),
                    ),
                  ] else ...[
                    _HChips(
                      items: _listingCats,
                      selected: _category,
                      onTap: (id) => setState(() => _category = id),
                      trailing: IconButton(
                        onPressed: () =>
                            ref.read(likedListingsProvider.notifier).refresh(),
                        icon: Icon(Icons.sync_rounded,
                            color: MatteSurface.muted(context)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SearchField(
                      controller: _search,
                      hint: 'Search title, description, location...',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Icon(Icons.swap_vert_rounded,
                              color: MatteSurface.muted(context), size: 18),
                          const SizedBox(width: 6),
                          for (final s in _sorts)
                            _SortChip(
                              label: s.$2,
                              selected: _sort == s.$1,
                              onTap: () => setState(() => _sort = s.$1),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_segment == 1)
            peopleAsync.when(
              loading: () => const _Spinner(),
              error: (_, _) => SliverFillRemaining(
                child: Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(likedPeopleProvider.notifier).refresh(),
                    child: const Text('Could not load people — retry'),
                  ),
                ),
              ),
              data: (people) {
                final q = _search.text.trim().toLowerCase();
                final filtered = people.where((p) {
                  if (q.isEmpty) return true;
                  return p.name.toLowerCase().contains(q) ||
                      (p.occupation ?? '').toLowerCase().contains(q);
                }).toList();
                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CapEmptyState(
                        variant: CapEmptyVariant.likes,
                        icon: Icons.favorite_border_rounded,
                        title: 'Network Empty.',
                        description:
                            'Your matches will appear here. Start scanning to find talent.',
                        actionLabel: 'EXPLORE',
                        onAction: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final person = filtered[i];
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
                        onMessage: () => _openChat(
                          userId: person.userId,
                          name: person.name,
                          avatar: person.primaryImage,
                        ),
                        onView: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProfileDetailScreen(userId: person.userId),
                            ),
                          );
                        },
                        onRemove: () async {
                          final ok = await _confirmRemove(person.name,
                              match: true);
                          if (!ok) return;
                          await ref
                              .read(likedPeopleProvider.notifier)
                              .remove(person.userId);
                        },
                      );
                    },
                  ),
                );
              },
            )
          else
            listingsAsync.when(
              loading: () => const _Spinner(),
              error: (_, _) => SliverFillRemaining(
                child: Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(likedListingsProvider.notifier).refresh(),
                    child: const Text('Could not load likes — retry'),
                  ),
                ),
              ),
              data: (listings) {
                var filtered = listings.where((l) {
                  if (_category != 'all' && l.category != _category) {
                    return false;
                  }
                  final q = _search.text.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  return (l.title ?? '').toLowerCase().contains(q) ||
                      (l.city ?? '').toLowerCase().contains(q) ||
                      (l.description ?? '').toLowerCase().contains(q);
                }).toList();
                filtered = [...filtered]..sort((a, b) {
                    switch (_sort) {
                      case 'oldest':
                        return (a.createdAt ?? DateTime(0))
                            .compareTo(b.createdAt ?? DateTime(0));
                      case 'price_up':
                        return (a.price ?? 0).compareTo(b.price ?? 0);
                      case 'price_down':
                        return (b.price ?? 0).compareTo(a.price ?? 0);
                      case 'az':
                        return (a.title ?? '').compareTo(b.title ?? '');
                      default:
                        return (b.createdAt ?? DateTime(0))
                            .compareTo(a.createdAt ?? DateTime(0));
                    }
                  });
                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CapEmptyState(
                        variant: CapEmptyVariant.likes,
                        icon: Icons.favorite_border_rounded,
                        title: 'Pure Potential.',
                        description:
                            'Your favorite listings will appear here. Start swiping to fill your world.',
                        actionLabel: 'EXPLORE WORLD',
                        onAction: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: filtered.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Text(
                          '● ${filtered.length} Saved Essentials',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFE4007C),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        );
                      }
                      return _ListingCard(
                        listing: filtered[index - 1],
                        onMessage: (l) => _openChat(
                          userId: l.ownerId ?? '',
                          name: l.title ?? 'Owner',
                          avatar: l.primaryImage,
                          listingId: l.id,
                        ),
                        onRemove: (l) async {
                          final ok = await _confirmRemove(
                            l.title ?? 'this listing',
                            match: false,
                          );
                          if (!ok) return;
                          await ref
                              .read(likedListingsProvider.notifier)
                              .remove(l.id);
                        },
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.onMessage,
    required this.onRemove,
  });

  final Listing listing;
  final void Function(Listing) onMessage;
  final void Function(Listing) onRemove;

  @override
  Widget build(BuildContext context) {
    final unit = listing.pricingUnit;
    final price = listing.price;
    return PremiumLikedCard(
      imageUrl: listing.primaryImage,
      title: listing.title ?? 'Listing',
      subtitle: listing.city ?? listing.location ?? listing.neighborhood ?? '',
      category: listing.category ?? listing.propertyType ?? 'Listing',
      description: listing.description,
      bedsLabel: listing.beds != null ? '${listing.beds}' : null,
      priceLabel: price == null
          ? null
          : '\$${price.toStringAsFixed(0)}${unit != null ? '/$unit' : '/mo'}',
      onMessage: () => onMessage(listing),
      onView: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listingData: listing),
          ),
        );
      },
      onRemove: () => onRemove(listing),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? _LikesScreenState._gradient : null,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF4D00).withAlpha(90),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : muted,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.6,
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
    final ink = MatteSurface.ink(context);
    final well = MatteSurface.well(context);
    final hairline = MatteSurface.hairline(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onTap(item.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected == item.$1
                        ? _LikesScreenState._gradient
                        : null,
                    color: selected == item.$1 ? null : well,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected == item.$1 ? Colors.transparent : hairline,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.$3,
                          size: 14,
                          color: selected == item.$1 ? Colors.white : ink),
                      const SizedBox(width: 6),
                      Text(
                        item.$2,
                        style: GoogleFonts.plusJakartaSans(
                          color: selected == item.$1 ? Colors.white : ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ?trailing,
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
    final ink = MatteSurface.ink(context);
    final well = MatteSurface.well(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected ? _LikesScreenState._gradient : null,
            color: selected ? null : well,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.transparent : MatteSurface.hairline(context),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: selected ? Colors.white : ink,
              fontWeight: FontWeight.w800,
              fontSize: 11,
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
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MatteSurface.well(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: ink, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: muted.withAlpha(160), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF4D00),
          strokeWidth: 2,
        ),
      ),
    );
  }
}
