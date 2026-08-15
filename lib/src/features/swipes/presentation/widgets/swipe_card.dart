import 'package:flutter/material.dart';

class SwipeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? price;
  final List<String> tags;
  final Widget? overlay;

  const SwipeCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.price,
    this.tags = const [],
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(32),
        // Dynamic box shadow happens in SwipeableCardStack via transform, but we give a base one here
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image background
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackGradient(),
            )
          else
            _buildFallbackGradient(),

          // Bottom gradient overlay - heavily weighted at the bottom like React app
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.5, 0.7, 0.9, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(80),
                    Colors.black.withAlpha(180),
                    Colors.black.withAlpha(240),
                  ],
                ),
              ),
            ),
          ),

          // Price badge top-left (Swipes puts tags top-left, price top-left)
          if (price != null)
            Positioned(
              top: 24,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.transparent, width: 1),
                ),
                child: Text(
                  price!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

          // Bottom info (Title and subtitle)
          Positioned(
            left: 20,
            right: 20,
            bottom: 120, // Leave room for action buttons
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.white.withAlpha(200),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      subtitle.isNotEmpty ? subtitle : 'Unknown Location',
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Overlay (Direction Stamps)
          overlay ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildFallbackGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
