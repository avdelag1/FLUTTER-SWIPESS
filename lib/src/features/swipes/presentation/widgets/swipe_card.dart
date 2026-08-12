import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

/// Premium swipe card with image background, gradient overlay, and glass info chips.
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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppTheme.brandPrimary.withAlpha(30),
            blurRadius: 60,
            offset: const Offset(0, 30),
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
              errorBuilder: (context, error, stackTrace) => _buildFallbackGradient(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildFallbackGradient(
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withAlpha(127),
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            )
          else
            _buildFallbackGradient(),

          // Bottom gradient overlay for text readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.7, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withAlpha(100),
                    Colors.black.withAlpha(200),
                  ],
                ),
              ),
            ),
          ),

          // Tags row at top
          if (tags.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: tags.take(3).map((tag) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _GlassChip(label: tag),
                )).toList(),
              ),
            ),

          // Price badge top-right
          if (price != null)
            Positioned(
              top: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.brandPrimary.withAlpha(80), width: 1),
                    ),
                    child: Text(
                      price!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom info
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: Colors.white.withAlpha(200), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 12)],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Custom overlay (e.g. swipe direction indicator)
          ?overlay,
        ],
      ),
    );
  }

  Widget _buildFallbackGradient({Widget? child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  const _GlassChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(40), width: 0.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
