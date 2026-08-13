import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/edit_listing_screen.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/my_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap PropertyManagement — Listing Control terminal.
class OwnerPropertiesScreen extends ConsumerStatefulWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  ConsumerState<OwnerPropertiesScreen> createState() =>
      _OwnerPropertiesScreenState();
}

class _OwnerPropertiesScreenState extends ConsumerState<OwnerPropertiesScreen> {
  String _tab = 'all';
  final _search = TextEditingController();

  static const _tabs = <(String, String, IconData)>[
    ('all', 'ALL', Icons.bolt_rounded),
    ('property', 'PROPERTIES', Icons.home_outlined),
    ('motorcycle', 'MOTORCYCLES', Icons.two_wheeler_rounded),
    ('bicycle', 'BICYCLES', Icons.pedal_bike_rounded),
    ('services', 'SERVICES', Icons.work_outline_rounded),
    ('likes', 'LIKES', Icons.thumb_up_alt_outlined),
    ('active', 'ACTIVE', Icons.check_circle_outline_rounded),
    ('rented', 'RENTED', Icons.home_work_outlined),
  ];

  static const _pink = Color(0xFFEB4898);
  static const _pinkDeep = Color(0xFFE4007C);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openChooser() {
    HapticFeedback.mediumImpact();
    showCreateListingChooser(context);
  }

  List<Listing> _visible(List<Listing> all) {
    Iterable<Listing> rows = all;
    switch (_tab) {
      case 'property':
        rows = rows.where((l) => l.category == null || l.category == 'property');
      case 'motorcycle':
        rows = rows.where((l) => l.category == 'motorcycle');
      case 'bicycle':
        rows = rows.where((l) => l.category == 'bicycle');
      case 'services':
        rows = rows.where(
          (l) => l.category == 'worker' || l.category == 'services',
        );
      case 'likes':
        rows = rows.where((l) => (l.likes ?? 0) > 0);
      case 'active':
        rows = rows.where(
          (l) => l.status == 'active' || l.isActive == true,
        );
      case 'rented':
        rows = rows.where((l) => l.status == 'rented');
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows.where((l) {
        final hay =
            '${l.title ?? ''} ${l.city ?? ''} ${l.category ?? ''} ${l.description ?? ''}'
                .toLowerCase();
        return hay.contains(q);
      });
    }
    return rows.toList();
  }

  int _count(List<Listing> all, String id) {
    switch (id) {
      case 'property':
        return all
            .where((l) => l.category == null || l.category == 'property')
            .length;
      case 'motorcycle':
        return all.where((l) => l.category == 'motorcycle').length;
      case 'bicycle':
        return all.where((l) => l.category == 'bicycle').length;
      case 'services':
        return all
            .where((l) => l.category == 'worker' || l.category == 'services')
            .length;
      case 'likes':
        return all.where((l) => (l.likes ?? 0) > 0).length;
      case 'active':
        return all
            .where((l) => l.status == 'active' || l.isActive == true)
            .length;
      case 'rented':
        return all.where((l) => l.status == 'rented').length;
      default:
        return all.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myListingsProvider('all'));
    final stats = ref.watch(ownerListingsStatsProvider);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: Stack(
        children: [
          const Positioned(
            top: -80,
            left: -40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x553B82F6), Color(0x00000000)],
                  ),
                ),
                child: SizedBox(width: 280, height: 220),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            right: -60,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x55EB4898), Color(0x00000000)],
                  ),
                ),
                child: SizedBox(width: 260, height: 220),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: top + 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      key: const Key('listing-control-spark'),
                      onTap: _openChooser,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0x1A6366F1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x336366F1)),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFF6366F1),
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LISTING CONTROL',
                            style: AppTheme.displayItalic.copyWith(
                              fontSize: 22,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'REAL-TIME ASSET MANAGEMENT PROTOCOL',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              fontSize: 9,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(AppPaths.ownerListingsNew),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_pinkDeep, _pink],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x59E11D48),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'ADD LISTING',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              stats.when(
                loading: () => const SizedBox(height: 8),
                error: (_, _) => const SizedBox.shrink(),
                data: (s) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _HudStat(
                              title: 'Total Listings',
                              value: '${s.total}',
                              detail: '${s.active} ACTIVE',
                              icon: Icons.home_outlined,
                              iconColor: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HudStat(
                              title: 'Total Views',
                              value: '${s.views}',
                              detail: 'ALL TIME',
                              icon: Icons.visibility_outlined,
                              iconColor: _pink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _HudStat(
                              title: 'Avg. Price',
                              value: s.avgPrice <= 0
                                  ? '\$0'
                                  : '\$${s.avgPrice.toStringAsFixed(0)}',
                              detail: 'PER LISTING',
                              icon: Icons.attach_money_rounded,
                              iconColor: _pink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HudStat(
                              title: 'Categories',
                              value: '${s.categories}',
                              detail: 'ACTIVE TYPES',
                              icon: Icons.monitor_heart_outlined,
                              iconColor: _pink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: Colors.white70, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                          cursorColor: _pink,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'SEARCH ASSETS...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: Colors.white24,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.6,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: async.maybeWhen(
                  data: (all) => ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _tabs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, i) {
                      final tab = _tabs[i];
                      final selected = _tab == tab.$1;
                      final count = _count(all, tab.$1);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _tab = tab.$1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: selected ? _pinkDeep : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: selected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x66E4007C),
                                      blurRadius: 18,
                                      offset: Offset(0, 6),
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                tab.$3,
                                size: 16,
                                color: selected
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tab.$2,
                                style: GoogleFonts.plusJakartaSans(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '[$count]',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.invalidate(myListingsProvider('all')),
                      child: const Text('Could not load listings — retry'),
                    ),
                  ),
                  data: (all) {
                    final listings = _visible(all);
                    if (listings.isEmpty) {
                      return _EmptyGallery(
                        searching: _search.text.trim().isNotEmpty,
                        onDeploy: _openChooser,
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: listings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _AssetCard(
                        listing: listings[index],
                        onChanged: () {
                          ref.invalidate(myListingsProvider('all'));
                          ref.invalidate(ownerListingsStatsProvider);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(102),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white60,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    fontSize: 9,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withAlpha(60)),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              fontSize: 26,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              fontSize: 9,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery({required this.searching, required this.onDeploy});

  final bool searching;
  final VoidCallback onDeploy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(
                searching
                    ? Icons.search_rounded
                    : Icons.auto_awesome_rounded,
                size: 48,
                color: searching
                    ? const Color(0x996366F1)
                    : const Color(0x99EB4898),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              searching ? 'SCAN NEGATIVE' : 'GALLERY EMPTY',
              style: AppTheme.displayItalic.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 12),
            Text(
              searching
                  ? 'No assets found matching current scan parameters. Adjust filters.'
                  : 'Your asset inventory is currently offline. Deploy your first listing to begin broadcast.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
            if (!searching) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: onDeploy,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE11D48), Color(0xFFEB4898)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'DEPLOY FIRST LISTING',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssetCard extends ConsumerWidget {
  const _AssetCard({required this.listing, required this.onChanged});
  final Listing listing;
  final VoidCallback onChanged;

  Future<void> _setStatus(BuildContext context, WidgetRef ref, String status) async {
    HapticFeedback.selectionClick();
    await ref.read(ownerListingsActionsProvider).setStatus(listing.id, status);
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status → $status')),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete listing?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Permanently remove "${listing.title ?? 'this listing'}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(ownerListingsActionsProvider).delete(listing.id);
    onChanged();
  }

  Future<void> _addPhotos(BuildContext context, WidgetRef ref) async {
    final files = await Navigator.of(context).push<List<XFile>>(
      MaterialPageRoute(
        builder: (_) => ListingCameraScreen(
          maxPhotos: 30,
          existingCount: listing.images.length,
        ),
      ),
    );
    if (files == null || files.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final repo = ref.read(listingRepositoryProvider);
    final ai = ref.read(aiEdgeRepositoryProvider);
    try {
      final urls = await repo.uploadListingPhotos(
        userId: user.id,
        files: files,
        moderateImage: ai.assertImageSafe,
      );
      await repo.appendListingImages(listingId: listing.id, imageUrls: urls);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${urls.length} photo(s)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _share(BuildContext context) async {
    final url = 'https://www.swipess.com/listing/${listing.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing link copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ListingDetailScreen(listingData: listing),
                ),
              );
            },
            child: SizedBox(
              height: 110,
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: listing.primaryImage != null
                        ? Image.network(listing.primaryImage!,
                            fit: BoxFit.cover)
                        : const ColoredBox(color: Color(0xFF16161C)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            listing.title ?? 'Untitled listing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            listing.formattedLocation,
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                listing.price == null
                                    ? (listing.category ?? 'LISTING')
                                        .toUpperCase()
                                    : '\$${listing.price!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppTheme.brandPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                (listing.status ?? 'active').toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  onSelected: (v) => _setStatus(context, ref, v),
                  color: const Color(0xFF14141A),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'active', child: Text('Active', style: TextStyle(color: Colors.white))),
                    PopupMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(color: Colors.white))),
                    PopupMenuItem(value: 'rented', child: Text('Rented', style: TextStyle(color: Colors.white))),
                    PopupMenuItem(value: 'sold', child: Text('Sold', style: TextStyle(color: Colors.white))),
                    PopupMenuItem(value: 'maintenance', child: Text('Maintenance', style: TextStyle(color: Colors.white))),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => EditListingScreen(listing: listing),
                      ),
                    );
                    if (updated == true) onChanged();
                  },
                  icon: const Icon(Icons.edit_rounded,
                      color: Colors.white70, size: 20),
                ),
                IconButton(
                  tooltip: 'Add photos',
                  onPressed: () => _addPhotos(context, ref),
                  icon: const Icon(Icons.photo_camera_rounded,
                      color: Colors.white70, size: 20),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_rounded,
                      color: Colors.white70, size: 20),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFF87171), size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
