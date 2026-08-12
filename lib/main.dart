import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

void main() {
  runApp(const NativeSwipeApp());
}

class NativeSwipeApp extends StatelessWidget {
  const NativeSwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Swipes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const SwiperScreen(),
    );
  }
}

class SwiperScreen extends StatefulWidget {
  const SwiperScreen({super.key});

  @override
  State<SwiperScreen> createState() => _SwiperScreenState();
}

class _SwiperScreenState extends State<SwiperScreen> {
  final CardSwiperController controller = CardSwiperController();

  final List<ExampleCard> cards = const [
    ExampleCard(
      title: 'Vibrant Sunset',
      description: 'Discover the beauty of the dusk.',
      colors: [Color(0xFFFF512F), Color(0xFFF09819)],
    ),
    ExampleCard(
      title: 'Ocean Deep',
      description: 'Dive into the unknown.',
      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
    ),
    ExampleCard(
      title: 'Forest Whisper',
      description: 'Nature is calling you.',
      colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
    ),
    ExampleCard(
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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

class ExampleCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Color> colors;

  const ExampleCard({
    super.key,
    required this.title,
    required this.description,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withAlpha(102),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
