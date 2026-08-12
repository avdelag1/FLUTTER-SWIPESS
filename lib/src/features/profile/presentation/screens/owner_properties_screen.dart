import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/my_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap OwnerProperties / PropertyManagement — list, stats, status, purge, camera.
class OwnerPropertiesScreen extends ConsumerStatefulWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  ConsumerState<OwnerPropertiesScreen> createState() =>
      _OwnerPropertiesScreenState();
}

class _OwnerPropertiesScreenState extends ConsumerState<OwnerPropertiesScreen> {
  int _selectedTab = 0;

  static const _tabs = [
    ('active', 'ACTIVE'),
    ('pending', 'PENDING'),
    ('rented', 'RENTED'),
    ('sold', 'SOLD'),
    ('maintenance', 'MAINT.'),
  ];

  String get _statusKey => _tabs[_selectedTab].$1;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myListingsProvider(_statusKey));
    final stats = ref.watch(ownerListingsStatsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateListingChooser(context),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add listing'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('MY LISTINGS',
                      style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                ],
              ),
            ),
            stats.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (s) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _Stat(label: 'Total', value: '${s.total}'),
                    _Stat(label: 'Active', value: '${s.active}'),
                    _Stat(label: 'Views', value: '${s.views}'),
                    _Stat(
                      label: 'Avg \$',
                      value: s.avgPrice <= 0
                          ? '—'
                          : s.avgPrice.toStringAsFixed(0),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _tabs.length,
                itemBuilder: (context, i) {
                  final selected = _selectedTab == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_tabs[i].$2),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedTab = i),
                      selectedColor: AppTheme.brandPrimary,
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                      backgroundColor: Colors.white.withAlpha(12),
                      side: BorderSide(color: Colors.white.withAlpha(30)),
                    ),
                  );
                },
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
                        ref.invalidate(myListingsProvider(_statusKey)),
                    child: const Text('Could not load listings — retry'),
                  ),
                ),
                data: (listings) {
                  if (listings.isEmpty) {
                    return Center(
                      child: Text(
                        'No listings in this tab.',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: listings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _AssetCard(
                      listing: listings[index],
                      onChanged: () {
                        ref.invalidate(myListingsProvider(_statusKey));
                        ref.invalidate(ownerListingsStatsProvider);
                      },
                    ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
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
        backgroundColor: const Color(0xFF14141A),
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
    final urls = await repo.uploadListingPhotos(
      userId: user.id,
      files: files,
    );
    await repo.appendListingImages(listingId: listing.id, imageUrls: urls);
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${urls.length} photo(s)')),
      );
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
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(25)),
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
