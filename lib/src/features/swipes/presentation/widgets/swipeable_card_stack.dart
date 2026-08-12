import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';

/// Callback with the swiped listing and direction.
typedef SwipeCallback = void Function(Listing listing, SwipeDirection direction);

enum SwipeDirection { left, right }

/// A stack of swipeable cards with Tinder-like physics.
///
/// Renders up to 3 cards in a stacked layout. The top card is draggable
/// with rotation proportional to horizontal displacement. Releasing past
/// the threshold triggers the swipe; otherwise it springs back.
class SwipeableCardStack extends StatefulWidget {
  final List<Listing> listings;
  final SwipeCallback onSwiped;
  final VoidCallback? onEmpty;
  final ValueChanged<Listing>? onTap;

  const SwipeableCardStack({
    super.key,
    required this.listings,
    required this.onSwiped,
    this.onEmpty,
    this.onTap,
  });

  @override
  SwipeableCardStackState createState() => SwipeableCardStackState();
}

class SwipeableCardStackState extends State<SwipeableCardStack>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  static const _swipeThreshold = 100.0;
  static const _maxRotation = 0.4; // radians (~23°)
  static const _maxVisibleCards = 3;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double get _rotation {
    if (!_isDragging) return 0;
    final screenWidth = MediaQuery.of(context).size.width;
    return (_dragOffset.dx / screenWidth) * _maxRotation;
  }

  double get _swipeProgress {
    return (_dragOffset.dx.abs() / _swipeThreshold).clamp(0.0, 1.0);
  }

  SwipeDirection? get _tentativeDirection {
    if (_dragOffset.dx.abs() < 20) return null;
    return _dragOffset.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
  }

  void _onPanStart(DragStartDetails details) {
    _snapController.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final shouldSwipe = _dragOffset.dx.abs() > _swipeThreshold || velocity.abs() > 800;

    if (shouldSwipe && widget.listings.isNotEmpty) {
      final direction = _dragOffset.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      _animateOffScreen(direction);
    } else {
      _animateSnapBack();
    }
  }

  void _animateOffScreen(SwipeDirection direction) {
    final screenWidth = MediaQuery.of(context).size.width;
    final endX = direction == SwipeDirection.right ? screenWidth * 1.5 : -screenWidth * 1.5;
    final endOffset = Offset(endX, _dragOffset.dy);

    _snapAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOut));

    _snapController.forward(from: 0).then((_) {
      HapticFeedback.mediumImpact();
      final swiped = widget.listings.first;
      widget.onSwiped(swiped, direction);
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
      _snapController.reset();
    });

    // Use animation listener to update offset during flyout
    _snapController.addListener(_updateFromAnimation);
  }

  void _updateFromAnimation() {
    if (_snapController.isAnimating) {
      setState(() {
        _dragOffset = _snapAnimation.value;
      });
    }
  }

  void _animateSnapBack() {
    _snapAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.elasticOut));

    _snapController.addListener(_updateFromAnimation);

    _snapController.forward(from: 0).then((_) {
      setState(() {
        _isDragging = false;
        _dragOffset = Offset.zero;
      });
      _snapController.removeListener(_updateFromAnimation);
      _snapController.reset();
    });
  }

  /// Programmatically trigger a swipe (from action buttons).
  void triggerSwipe(SwipeDirection direction) {
    if (widget.listings.isEmpty) return;
    HapticFeedback.lightImpact();
    _animateOffScreen(direction);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listings.isEmpty) {
      return _buildEmptyState();
    }

    final visibleCount = min(_maxVisibleCards, widget.listings.length);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background cards (rendered bottom to top)
        for (int i = visibleCount - 1; i > 0; i--)
          _buildBackCard(i, widget.listings[i]),

        // Top card (draggable)
        _buildTopCard(widget.listings.first),
      ],
    );
  }

  Widget _buildBackCard(int index, Listing listing) {
    final scale = 1.0 - (index * 0.04);
    final translateY = index * 12.0;

    return Positioned.fill(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          // ignore: deprecated_member_use
          ..scale(scale)
          // ignore: deprecated_member_use
          ..translate(0.0, translateY),
        child: Opacity(
          opacity: 1.0 - (index * 0.15),
          child: IgnorePointer(
            child: SwipeCard(
              title: listing.title ?? 'Listing',
              subtitle: listing.formattedLocation,
              imageUrl: listing.primaryImage,
              price: listing.formattedPrice,
              tags: listing.quickTags.take(2).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard(Listing listing) {
    return Positioned.fill(
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: () => widget.onTap?.call(listing),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            // ignore: deprecated_member_use
            ..translate(_dragOffset.dx, _dragOffset.dy)
            ..rotateZ(_rotation),
          child: Stack(
            children: [
              SwipeCard(
                title: listing.title ?? 'Listing',
                subtitle: listing.formattedLocation,
                imageUrl: listing.primaryImage,
                price: listing.formattedPrice,
                tags: listing.quickTags.take(3).toList(),
              ),

              // LIKE overlay
              if (_tentativeDirection == SwipeDirection.right)
                Positioned(
                  top: 40,
                  left: 24,
                  child: _SwipeLabel(
                    text: 'LIKE',
                    color: const Color(0xFF22C55E),
                    icon: Icons.favorite_rounded,
                    opacity: _swipeProgress,
                  ),
                ),

              // NOPE overlay
              if (_tentativeDirection == SwipeDirection.left)
                Positioned(
                  top: 40,
                  right: 24,
                  child: _SwipeLabel(
                    text: 'NOPE',
                    color: const Color(0xFFEF4444),
                    icon: Icons.close_rounded,
                    opacity: _swipeProgress,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.brandPrimary.withAlpha(30),
            ),
            child: Icon(Icons.explore_rounded, color: AppTheme.brandPrimary.withAlpha(180), size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No more listings',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or check back later',
            style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Swipe Direction Label ─────────────────────────────────────────────────────

class _SwipeLabel extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  final double opacity;

  const _SwipeLabel({
    required this.text,
    required this.color,
    required this.icon,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: 0.8 + (opacity * 0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 3),
            color: color.withAlpha(51),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
