import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipeable_card_stack.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_action_button_bar.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';

/// The swipe tab content — lives inside DashboardShell.
/// Now loads REAL listings from Supabase and records swipes.
class SwipeTabContent extends ConsumerWidget {
  const SwipeTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(swipeFeedProvider);
    final swipeRepo = ref.read(swipeRepositoryProvider);
    final feedNotifier = ref.read(swipeFeedProvider.notifier);
    final historyNotifier = ref.read(swipeHistoryProvider.notifier);

    return feedAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white.withAlpha(127), size: 48),
              const SizedBox(height: 16),
              Text(
                'Could not load listings',
                style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Colors.white.withAlpha(102), fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => feedNotifier.refresh(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
      data: (listings) => Column(
        children: [
          // Push below the top bar
          SizedBox(height: MediaQuery.of(context).padding.top + 64),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SwipeableCardStack(
                listings: listings,
                onSwiped: (listing, direction) async {
                  // Record to history for undo
                  historyNotifier.push(listing);
                  // Remove from feed
                  feedNotifier.removeTop();
                  // Record to Supabase
                  if (direction == SwipeDirection.right) {
                    await swipeRepo.likeListing(listing.id);
                    // Check for match
                    final isMatch = await swipeRepo.checkForMatch(listing.id);
                    if (isMatch && context.mounted) {
                      _showMatchDialog(context, listing.title ?? 'Listing');
                    }
                  } else {
                    await swipeRepo.dislikeListing(listing.id);
                  }
                },
                onTap: (listing) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ListingDetailScreen(listingId: listing.id),
                    ),
                  );
                },
              ),
            ),
          ),

          // Swipe Action Buttons
          SwipeActionButtonBar(
            onLike: () {
              // Programmatic swipe right - would need a GlobalKey to trigger
              // For now, the drag gesture is the primary input
            },
            onDislike: () {},
            onUndo: () {
              final undone = historyNotifier.pop();
              if (undone != null) {
                feedNotifier.undoRemove(undone);
                swipeRepo.undoSwipe(undone.id);
              }
            },
            onMessage: () {},
            onInsights: () {},
          ),

          // Space for bottom nav
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showMatchDialog(BuildContext context, String listingTitle) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                "It's a Match!",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'You and the owner of "$listingTitle" are interested!',
                style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Keep Swiping', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
