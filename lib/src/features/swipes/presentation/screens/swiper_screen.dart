import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_action_button_bar.dart';

/// The swipe tab content — lives inside DashboardShell.
class SwipeTabContent extends ConsumerWidget {
  const SwipeTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Push below the top bar
        SizedBox(height: MediaQuery.of(context).padding.top + 64),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SwipeCard(
              title: 'Luxury Penthouse',
              subtitle: 'Miami Beach, FL',
              price: '\$2,500/mo',
              tags: const ['Furnished', 'Ocean View', 'Premium'],
              imageUrl: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=2075&q=80',
            ),
          ),
        ),

        // Swipe Action Buttons
        SwipeActionButtonBar(
          onLike: () {},
          onDislike: () {},
          onUndo: () {},
          onMessage: () {},
          onInsights: () {},
        ),
        
        // Space for bottom nav
        const SizedBox(height: 80),
      ],
    );
  }
}
