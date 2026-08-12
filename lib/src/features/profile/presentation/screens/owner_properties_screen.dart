import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/my_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class OwnerPropertiesScreen extends ConsumerStatefulWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  ConsumerState<OwnerPropertiesScreen> createState() =>
      _OwnerPropertiesScreenState();
}

class _OwnerPropertiesScreenState extends ConsumerState<OwnerPropertiesScreen> {
  int _selectedTab = 0;

  String get _statusKey {
    switch (_selectedTab) {
      case 1:
        return 'pending';
      case 2:
        return 'sold';
      default:
        return 'active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myListingsProvider(_statusKey));

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context);
          ref.read(navTabProvider.notifier).set(NavTab.add);
        },
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
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('MY LISTINGS', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(25)),
                ),
                child: Row(
                  children: [
                    _buildTab('ACTIVE', 0),
                    _buildTab('PENDING', 1),
                    _buildTab('SOLD', 2),
                  ],
                ),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(myListingsProvider(_statusKey)),
                    child: const Text('Could not load listings — retry'),
                  ),
                ),
                data: (listings) {
                  if (listings.isEmpty) {
                    return Center(
                      child: Text(
                        'No listings in this tab.',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: listings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _AssetCard(listing: listings[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listingData: listing),
          ),
        );
      },
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: listing.primaryImage != null
                  ? Image.network(listing.primaryImage!, fit: BoxFit.cover)
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.formattedLocation,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      listing.price == null
                          ? (listing.category ?? 'LISTING').toUpperCase()
                          : '\$${listing.price!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.brandPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
