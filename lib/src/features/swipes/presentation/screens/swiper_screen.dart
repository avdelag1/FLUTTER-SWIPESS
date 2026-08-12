import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      title: 'Vibrant Sunset',
      description: 'Discover the beauty of the dusk.',
      colors: [Color(0xFFFF512F), Color(0xFFF09819)],
    ),
    SwipeCard(
      title: 'Ocean Deep',
      description: 'Dive into the unknown.',
      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
    ),
    SwipeCard(
      title: 'Forest Whisper',
      description: 'Nature is calling you.',
      colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
    ),
    SwipeCard(
      title: 'Cosmic Void',
      description: 'Journey to the stars.',
      colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
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
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.only(bottom: 30.0, top: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: () => controller.swipe(CardSwiperDirection.left),
                    backgroundColor: Colors.white12,
                    elevation: 0,
                    child: const Icon(Icons.close, color: Colors.redAccent, size: 30),
                  ),
                  FloatingActionButton(
                    onPressed: () => controller.swipe(CardSwiperDirection.top),
                    backgroundColor: Colors.white12,
                    elevation: 0,
                    child: const Icon(Icons.star, color: Colors.blueAccent, size: 30),
                  ),
                  FloatingActionButton(
                    onPressed: () => controller.swipe(CardSwiperDirection.right),
                    backgroundColor: Colors.white12,
                    elevation: 0,
                    child: const Icon(Icons.favorite, color: Colors.greenAccent, size: 30),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
