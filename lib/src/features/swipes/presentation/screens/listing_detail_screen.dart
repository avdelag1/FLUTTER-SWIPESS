import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

final listingByIdProvider = FutureProvider.family<Listing?, String>((ref, id) {
  return ref.read(listingRepositoryProvider).fetchById(id);
});

class ListingDetailScreen extends ConsumerWidget {
  final Listing? listingData;
  final String? listingId;

  const ListingDetailScreen({
    super.key,
    this.listingData,
    this.listingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listingData != null) {
      return _ListingDetailBody(listing: listingData!);
    }
    final id = listingId;
    if (id == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Listing not found', style: TextStyle(color: Colors.white))),
      );
    }
    final async = ref.watch(listingByIdProvider(id));
    return async.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Could not load listing: $e', style: const TextStyle(color: Colors.white))),
      ),
      data: (listing) {
        if (listing == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: Text('Listing not found', style: TextStyle(color: Colors.white))),
          );
        }
        return _ListingDetailBody(listing: listing);
      },
    );
  }
}

class _ListingDetailBody extends StatelessWidget {
  const _ListingDetailBody({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          Positioned.fill(
            child: SwipeCard(
              title: listing.title ?? 'Unknown',
              subtitle: listing.formattedLocation,
              imageUrl: listing.primaryImage,
              price: listing.formattedPrice,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(127),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(50)),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D00).withAlpha(200),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFF4D00)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFF4D00).withAlpha(127), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Center(
                      child: Text('MESSAGE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: const Center(
                    child: Icon(Icons.share_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
