import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';

class RoommateMatchingScreen extends StatelessWidget {
  const RoommateMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: SwipeCard(
              title: 'Michael, 28',
              subtitle: 'Looking for a roommate in Brickell',
              imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
              price: 'Budget: \$2k/mo',
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
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(50)),
                      ),
                      child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(100),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('FILTERS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
