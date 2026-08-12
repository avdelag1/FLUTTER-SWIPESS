import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

class ListingDetailScreen extends ConsumerWidget {
  final Listing? listingData;

  const ListingDetailScreen({
    super.key,
    required this.listingData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Dimmer
          Positioned.fill(
            child: Container(color: Colors.black),
          ),
          
          // Full Screen Static Card
          Positioned.fill(
            child: SwipeCard(
              title: listingData?.title ?? 'Unknown',
              subtitle: listingData?.location ?? 'No Location',
              imageUrl: listingData?.images.isNotEmpty == true ? listingData!.images.first : null,
              price: listingData?.price != null ? '\$${listingData!.price}' : null,
            ),
          ),
          
          // Top Nav (Back Button)
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
          
          // Action Bar Override
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
