import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/who_liked_you_screen.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen> {
  int _segment = 0; // 0 listings, 1 people
  String _category = 'all';
  String _sort = 'newest';
  final _search = TextEditingController();

  static const _gradient = LinearGradient(
    colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final listingsAsync = ref.watch(likedListingsProvider);

    return ColoredBox(
      color: Colors.black,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, top + 64, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withAlpha(25)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _Seg(label: 'LIKED LISTINGS', selected: _segment == 0, onTap: () => setState(() => _segment = 0))),
                        Expanded(child: _Seg(label: 'LIKED PEOPLE', selected: _segment == 1, onTap: () => setState(() => _segment = 1))),
                      ],
                    ),
                  ),
                  if (_segment == 0) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _Chip(
                            label: 'All Favorites',
                            icon: Icons.local_fire_department_rounded,
                            selected: _category == 'all',
                            onTap: () => setState(() => _category = 'all'),
                          ),
                          _Chip(
                            label: 'Properties',
                            icon: Icons.home_rounded,
                            selected: _category == 'property',
                            onTap: () => setState(() => _category = 'property'),
                          ),
                          _Chip(
                            label: 'Vehicles',
                            icon: Icons.directions_car_rounded,
                            selected: _category == 'vehicle',
                            onTap: () => setState(() => _category = 'vehicle'),
                          ),
                          IconButton(
                            onPressed: () => ref.read(likedListingsProvider.notifier).refresh(),
                            icon: const Icon(Icons.sync_rounded, color: Colors.white70, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Search title, description, location...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          const Icon(Icons.swap_vert_rounded, color: Colors.white38, size: 18),
                          const SizedBox(width: 6),
                          for (final s in const [
                            ('newest', 'NEWEST'),
                            ('oldest', 'OLDEST'),
                            ('price_up', 'PRICE ↑'),
                            ('price_down', 'PRICE ↓'),
                            ('az', 'A → Z'),
                          ])
                            _Chip(
                              label: s.$2,
                              selected: _sort == s.$1,
                              onTap: () => setState(() => _sort = s.$1),
                              compact: true,
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WhoLikedYouScreen()),
                    );
                  },
                  child: const Text('Open who liked you →'),
                ),
              ),
            )
          else
            listingsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              ),
              error: (_, _) => SliverFillRemaining(
                child: Center(
                  child: TextButton(
                    onPressed: () => ref.read(likedListingsProvider.notifier).refresh(),
                    child: const Text('Could not load likes — retry'),
                  ),
                ),
              ),
              data: (listings) {
                var filtered = listings.where((l) {
                  if (_category == 'property' && l.category != 'property') return false;
                  if (_category == 'vehicle' &&
                      l.category != 'motorcycle' &&
                      l.category != 'bicycle' &&
                      l.category != 'yacht') {
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
                        return (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0));
                      case 'price_up':
                        return (a.price ?? 0).compareTo(b.price ?? 0);
                      case 'price_down':
                        return (b.price ?? 0).compareTo(a.price ?? 0);
                      case 'az':
                        return (a.title ?? '').compareTo(b.title ?? '');
                      default:
                        return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
                    }
                  });

                if (filtered.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('Swipe right to save listings here.', style: TextStyle(color: Colors.white70)),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '● ${filtered.length} SAVED ESSENTIALS',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFEB4898),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _LikedCard(listing: filtered[index - 1]),
                        );
                      },
                      childCount: filtered.length + 1,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? _LikesScreenState._gradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 7 : 8),
          decoration: BoxDecoration(
            gradient: selected ? _LikesScreenState._gradient : null,
            color: selected ? null : const Color(0xFF1A1A20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(selected ? 0 : 25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikedCard extends StatelessWidget {
  const _LikedCard({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (listing.primaryImage != null)
                  Image.network(listing.primaryImage!, fit: BoxFit.cover)
                else
                  const ColoredBox(color: Color(0xFF16161C)),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      (listing.category ?? 'LISTING').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
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
                        listing.title ?? 'Untitled',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFFEB4898), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            listing.city ?? listing.formattedLocation,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEB4898),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (listing.bedrooms != null) ...[
                      const Icon(Icons.bed_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text('${listing.bedrooms}', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(width: 12),
                    ],
                    if (listing.price != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFEB4898)),
                        ),
                        child: Text(
                          '\$${listing.price!.toStringAsFixed(0)}/month',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEB4898),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if ((listing.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    listing.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final ownerId = listing.ownerId;
                          if (ownerId == null) return;
                          final convoId = await SwipeRepository()
                              .startConversation(ownerId: ownerId, listingId: listing.id);
                          if (!context.mounted || convoId == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversation: ChatConversation(
                                  id: convoId,
                                  otherUserId: ownerId,
                                  name: listing.title ?? 'Owner',
                                  lastMessage: '',
                                  timestamp: 'now',
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                        label: const Text('MESSAGE'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEB4898),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ListingDetailScreen(listingData: listing),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('VIEW'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withAlpha(60)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
