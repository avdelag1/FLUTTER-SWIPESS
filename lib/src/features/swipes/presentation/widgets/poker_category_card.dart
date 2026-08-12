import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';

class PokerCardData {
  final String id;
  final String title;
  final String imageUrl;

  const PokerCardData({
    required this.id,
    required this.title,
    required this.imageUrl,
  });
}

class PokerCategoryCard extends StatelessWidget {
  final PokerCardData card;
  final int index;
  final int total;
  final bool isTop;
  final Function(String, bool) onCycle; // true = right, false = left
  final Function(int) onBringToFront;

  const PokerCategoryCard({
    super.key,
    required this.card,
    required this.index,
    required this.total,
    required this.isTop,
    required this.onCycle,
    required this.onBringToFront,
  });

  @override
  Widget build(BuildContext context) {
    if (index > 4) return const SizedBox.shrink(); // Only show top 5

    // Stack positioning math to mimic framer-motion deck
    final double yOffset = index * 12.0;
    final double scale = 1 - (index * 0.05);
    final double zRotation = (index % 2 == 0 ? -1 : 1) * index * 0.02;

    return isTop ? _buildDraggableCard(context) : _buildBackgroundCard(context, yOffset, scale, zRotation);
  }

  Widget _buildBackgroundCard(BuildContext context, double yOffset, double scale, double zRotation) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: yOffset,
      bottom: -yOffset,
      child: GestureDetector(
        onTap: () => onBringToFront(index),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, scale, 1)
            ..rotateZ(zRotation),
          child: _buildCardContent(),
        ),
      ),
    );
  }

  Widget _buildDraggableCard(BuildContext context) {
    return Draggable<String>(
      data: card.id,
      feedback: Transform.rotate(
        angle: 0.05,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.4,
          child: Opacity(opacity: 0.9, child: _buildCardContent()),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      onDragEnd: (details) {
        if (details.offset.dx.abs() > 100 || details.velocity.pixelsPerSecond.dx.abs() > 500) {
          onCycle(card.id, details.offset.dx > 0);
        }
      },
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientSwipeContainer(
                categoryId: card.id,
                categoryTitle: card.title,
              ),
            ),
          );
        },
        child: _buildCardContent(),
      ),
    );
  }

  Widget _buildCardContent() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        image: DecorationImage(
          image: NetworkImage(card.imageUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                colors: [Colors.black.withAlpha(50), Colors.black.withAlpha(180)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            child: Text(
              card.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
