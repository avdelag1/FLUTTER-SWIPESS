import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:go_router/go_router.dart';

/// Ensures every map opening starts with a fresh discovery request instead of
/// reusing an old cached empty/error FutureProvider result.
class FreshMapboxScreen extends ConsumerStatefulWidget {
  const FreshMapboxScreen({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<FreshMapboxScreen> createState() => _FreshMapboxScreenState();
}

class _FreshMapboxScreenState extends ConsumerState<FreshMapboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshData();
    });
  }

  void _refreshData() {
    ref.invalidate(mapListingsProvider);
    ref.invalidate(mapProfilesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(mapListingsProvider);
    final profiles = ref.watch(mapProfilesProvider);
    final listingRows = listings.value ?? const <Listing>[];
    final loading = listings.isLoading || profiles.isLoading;
    final failed = listings.hasError || profiles.hasError;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        RealMapboxScreen(
          onClose: widget.onClose,
          showCitiesOnOpen: widget.showCitiesOnOpen,
        ),
        if (loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: Color(0xFF60A5FA),
            ),
          ),
        if (listingRows.isNotEmpty)
          Positioned(
            left: 12,
            right: 64,
            bottom: bottom + 78,
            child: _CompactListingStrip(
              listings: listingRows,
              onOpen: (listing) => context.push('/listing/${listing.id}'),
            ),
          ),
        if (failed)
          Positioned(
            left: 12,
            bottom: bottom + 18,
            child: Material(
              color: Colors.black.withAlpha(170),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _refreshData,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withAlpha(65),
                      width: .7,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'RETRY MAP DATA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactListingStrip extends StatelessWidget {
  const _CompactListingStrip({required this.listings, required this.onOpen});

  final List<Listing> listings;
  final ValueChanged<Listing> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: listings.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final listing = listings[index];
          final image = listing.primaryImage;
          return Material(
            color: Colors.black.withAlpha(155),
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onOpen(listing),
              child: Container(
                width: 148,
                padding: const EdgeInsets.fromLTRB(5, 5, 9, 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withAlpha(58),
                    width: .7,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: image != null && image.isNotEmpty
                            ? Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFF242830),
                                  child: Icon(
                                    Icons.home_work_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              )
                            : const ColoredBox(
                                color: Color(0xFF242830),
                                child: Icon(
                                  Icons.home_work_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.title?.trim().isNotEmpty == true
                                ? listing.title!.trim()
                                : 'Listing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            listing.formattedPrice,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(175),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
