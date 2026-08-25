import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_empty_state.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
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

/// Unified saved/liked content screen.
///
/// Kept deliberately compact because this route already lives inside the
/// dashboard shell. The shell owns the top navigation; this screen should not
/// add another large framed header beneath it.
class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen> {
  static const _accent = Color(0xFFFF4D00); // Swipess Neon Orange
  static const _accent2 = Color(0xFFEB4898); // Vibrant Pink
  static const _accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_accent, _accent2],
  );

  int _segment = 0;
  String _category = 'all';
  String _sort = 'newest';
  final _search = TextEditingController();

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
    });
  }

  Future<void> _openChat({
    required String userId,
    required String name,
    String? avatar,
    String? listingId,
  }) async {
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

  Future<bool> _confirmRemove(String title, {required bool match}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          match ? 'Remove match?' : 'Remove from likes?',
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.ink(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          match
              ? 'Remove $title from your saved people?'
              : 'Remove “$title” from your saved listings?',
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.muted(context),
          ),
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
                color: const Color(0xFFFF5C7A),
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
    final muted = MatteSurface.muted(context);

    return ColoredBox(
      color: MatteSurface.canvas(context),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              // The dashboard shell already provides the route chrome/back
              // button. Keep this content close to it instead of reserving a
              // second 64px header block.
              padding: EdgeInsets.fromLTRB(16, top + 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_segment == 1) ...[
                    Row(
                      children: [
                        Text(
                          'Saved people',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        _MiniAction(
                          label: 'Liked me',
                          icon: Icons.favorite_border_rounded,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WhoLikedYouScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _HChips(
                      items: _peopleCats,
                      selected: _category,
                      onTap: (id) => setState(() => _category = id),
                    ),
                    const SizedBox(height: 8),
                    _SearchField(
                      controller: _search,
                      hint: 'Search people',
                      onChanged: (_) => setState(() {}),
                    ),
                  ] else ...[
                    _HChips(
                      items: _listingCats,
                      selected: _category,
                      onTap: (id) => setState(() => _category = id),
                      trailing: _RefreshAction(
                        onTap: () =>
                            ref.read(likedListingsProvider.notifier).refresh(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SearchField(
                      controller: _search,
                      hint: 'Search saved listings',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: Icon(
                              Icons.swap_vert_rounded,
                              color: muted,
                              size: 16,
                            ),
                          ),
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
                final filtered = people.where((person) {
                  if (_category != 'all') {
                    final occupation = (person.occupation ?? '').toLowerCase();
                    if (!occupation.contains(_category)) return false;
                  }
                  if (q.isEmpty) return true;
                  return person.name.toLowerCase().contains(q) ||
                      (person.occupation ?? '').toLowerCase().contains(q) ||
                      (person.bio ?? '').toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CapEmptyState(
                        variant: CapEmptyVariant.likes,
                        icon: Icons.favorite_border_rounded,
                        title: 'Nothing saved yet.',
                        description:
                            'People you save will appear here so you can come back anytime.',
                        actionLabel: 'EXPLORE',
                        onAction: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final person = filtered[index];
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
                          final ok = await _confirmRemove(
                            person.name,
                            match: true,
                          );
                          if (!ok) return;
                          await ref
                              .read(likedPeopleProvider.notifier)
                              .remove(person.userId);
                          ref.read(appNotificationsProvider.notifier).show(
                            title: 'Removed',
                            message: '${person.name} was removed from your likes',
                            type: AppToastType.info,
                          );
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
                var filtered = listings.where((listing) {
                  if (_category != 'all' && listing.category != _category) {
                    return false;
                  }
                  final q = _search.text.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  return (listing.title ?? '').toLowerCase().contains(q) ||
                      (listing.city ?? '').toLowerCase().contains(q) ||
                      (listing.description ?? '').toLowerCase().contains(q);
                }).toList();

                filtered = [...filtered]
                  ..sort((a, b) {
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

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CapEmptyState(
                        variant: CapEmptyVariant.likes,
                        icon: Icons.favorite_border_rounded,
                        title: 'Nothing saved yet.',
                        description:
                            'Your favorite listings will appear here as you explore SWIPESS.',
                        actionLabel: 'EXPLORE',
                        onAction: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '${filtered.length} saved',
                                style: GoogleFonts.plusJakartaSans(
                                  color: muted,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final listing = filtered[index];
                          return _ListingCard(
                            listing: listing,
                            onMessage: (item) => _openChat(
                              userId: item.ownerId ?? '',
                              name: item.title ?? 'Owner',
                              avatar: item.primaryImage,
                              listingId: item.id,
                            ),
                            onRemove: (item) async {
                              final ok = await _confirmRemove(
                                item.title ?? 'this listing',
                                match: false,
                              );
                              if (!ok) return;
                              await ref
                                  .read(likedListingsProvider.notifier)
                                  .remove(item.id);
                              ref.read(appNotificationsProvider.notifier).show(
                                title: 'Removed',
                                message: 'Listing was removed from your likes',
                                type: AppToastType.info,
                              );
                            },
                          );
                        }, childCount: filtered.length),
                      ),
                    ],
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
    final ink = MatteSurface.ink(context);
    final well = MatteSurface.well(context);
    final hairline = MatteSurface.hairline(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? _LikesScreenState._accentGradient : null,
          color: selected ? null : well,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : hairline,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _LikesScreenState._accent.withAlpha(45),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : (ink.withAlpha(220)),
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.4,
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
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  onTap(item.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: selected == item.$1
                        ? _LikesScreenState._accentGradient
                        : null,
                    color: selected == item.$1 ? null : well,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected == item.$1
                          ? Colors.transparent
                          : hairline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$3,
                        size: 13,
                        color: selected == item.$1 ? Colors.white : ink,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.$2,
                        style: GoogleFonts.plusJakartaSans(
                          color: selected == item.$1 ? Colors.white : ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
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
    final ink = MatteSurface.ink(context);
    final well = MatteSurface.well(context);
    final hairline = MatteSurface.hairline(context);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? _LikesScreenState._accent.withAlpha(30)
                : well,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? _LikesScreenState._accent.withAlpha(120)
                  : hairline,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: selected ? _LikesScreenState._accent : ink,
              fontWeight: FontWeight.w800,
              fontSize: 10,
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
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: MatteSurface.well(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: muted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: muted.withAlpha(170),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
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

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _LikesScreenState._accent.withAlpha(22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _LikesScreenState._accent.withAlpha(80),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_border_rounded,
              color: _LikesScreenState._accent,
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: _LikesScreenState._accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MatteSurface.well(context),
          shape: BoxShape.circle,
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        child: Icon(Icons.sync_rounded, color: muted, size: 16),
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
          color: _LikesScreenState._accent,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
