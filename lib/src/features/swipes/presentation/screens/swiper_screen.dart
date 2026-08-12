import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import '../widgets/swipe_card.dart';

class SwiperScreen extends ConsumerStatefulWidget {
  const SwiperScreen({super.key});

  @override
  ConsumerState<SwiperScreen> createState() => _SwiperScreenState();
}

class _SwiperScreenState extends ConsumerState<SwiperScreen> {
  final CardSwiperController controller = CardSwiperController();

  final List<SwipeCard> cards = const [
    SwipeCard(
      title: 'Discover 2026',
      description: 'The future of Swipess, now entirely native.',
    ),
    SwipeCard(
      title: 'Fluid Gestures',
      description: 'Feel the 120fps spring physics.',
    ),
    SwipeCard(
      title: 'Cinematic Shadows',
      description: 'Directly translated from your CSS tokens.',
    ),
    SwipeCard(
      title: 'Native Power',
      description: 'Connected directly to your Supabase.',
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swipess', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CardSwiper(
                controller: controller,
                cardsCount: cards.length,
                numberOfCardsDisplayed: 3,
                backCardOffset: const Offset(0, 40),
                padding: const EdgeInsets.all(24.0),
                cardBuilder: (
                  context,
                  index,
                  horizontalThresholdPercentage,
                  verticalThresholdPercentage,
                ) =>
                    cards[index],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0, top: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.close_rounded,
                    color: Colors.white,
                    bgColor: AppTheme.glassBg,
                    onPressed: () => controller.swipe(CardSwiperDirection.left),
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: Icons.favorite_rounded,
                    color: Colors.white,
                    bgColor: AppTheme.brandPrimary,
                    onPressed: () => controller.swipe(CardSwiperDirection.right),
                    isPrimary: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withAlpha(25),
          width: 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppTheme.brandPrimary.withAlpha(100),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: isPrimary ? 40 : 32),
        padding: EdgeInsets.all(isPrimary ? 20 : 16),
        onPressed: onPressed,
      ),
    );
  }
}
