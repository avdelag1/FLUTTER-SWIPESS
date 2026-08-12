import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipeable_card_stack.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_action_button_bar.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_providers.dart';
import 'dart:ui';

class ClientSwipeContainer extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryTitle;

  const ClientSwipeContainer({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  @override
  ConsumerState<ClientSwipeContainer> createState() => _ClientSwipeContainerState();
}

class _ClientSwipeContainerState extends ConsumerState<ClientSwipeContainer> {
  final GlobalKey<SwipeableCardStackState> _stackKey = GlobalKey<SwipeableCardStackState>();

  void _handleLike() {
    _stackKey.currentState?.triggerSwipe(SwipeDirection.right);
  }

  void _handleDislike() {
    _stackKey.currentState?.triggerSwipe(SwipeDirection.left);
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(swipeListingsProvider(widget.categoryId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Map / Glow
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F172A), // Slate 900
            ),
          ),
          
          // Swipe Deck
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 60, bottom: 0),
                child: listingsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  error: (err, stack) => Center(child: Text('Error loading swipes: $err', style: const TextStyle(color: Colors.red))),
                  data: (listings) {
                    if (listings.isEmpty) {
                      return const Center(child: Text("You've seen all listings in this category!", style: TextStyle(color: Colors.white, fontSize: 16)));
                    }
                    return SwipeableCardStack(
                      key: _stackKey,
                      listings: listings, // Now using real Supabase data
                      onSwiped: (listing, direction) {
                        final authUser = ref.read(currentProfileProvider).value?.id;
                        if (authUser != null) {
                          if (direction == SwipeDirection.right) {
                            ref.read(swipeRepositoryProvider).registerSwipeRight(authUser, listing.id);
                          } else {
                            ref.read(swipeRepositoryProvider).registerSwipeLeft(authUser, listing.id);
                          }
                        }
                      },
                      onTap: (listing) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(listingData: listing),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Floating Top Rail
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassPillButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(40), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.categoryTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _GlassPillButton(
                  icon: Icons.tune_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Floating Action Bar (Bottom)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: SwipeActionButtonBar(
              onLike: _handleLike,
              onDislike: _handleDislike,
              onUndo: () {},
              onMessage: () {},
              onInsights: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassPillButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 20)),
          ),
        ),
      ),
    );
  }
}
