import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';

typedef SwipeCallback = void Function(Listing listing, SwipeDirection direction);
enum SwipeDirection { left, right }

class SwipeableCardStack extends StatefulWidget {
  final List<Listing> listings;
  final SwipeCallback onSwiped;
  final ValueChanged<Listing>? onTap;

  const SwipeableCardStack({
    super.key,
    required this.listings,
    required this.onSwiped,
    this.onTap,
  });

  @override
  State<SwipeableCardStack> createState() => SwipeableCardStackState();
}

class SwipeableCardStackState extends State<SwipeableCardStack> with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  static const _swipeThreshold = 100.0;
  static const _maxVisibleCards = 3;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double get _rotation {
    if (!_isDragging && !_snapController.isAnimating) return 0;
    // RotateZ up to 18 degrees (0.31 radians) over 400px
    return (_dragOffset.dx / 400).clamp(-1.0, 1.0) * 0.31;
  }
  
  double get _rotateY {
    // RotateY up to 25 degrees (0.43 radians) over 400px
    return (_dragOffset.dx / 400).clamp(-1.0, 1.0) * -0.43;
  }
  
  double get _rotateX {
    // RotateX up to 15 degrees (0.26 radians) over 400px
    return (_dragOffset.dy / 400).clamp(-1.0, 1.0) * 0.26;
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
    setState(() => _dragOffset += details.delta);
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
    
    _snapAnimation = Tween<Offset>(begin: _dragOffset, end: Offset(endX, _dragOffset.dy))
      .animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic));

    _snapController.forward(from: 0).then((_) {
      if (direction == SwipeDirection.right) { HapticFeedback.heavyImpact(); } else { HapticFeedback.mediumImpact(); }
      
      final swiped = widget.listings.first;
      widget.onSwiped(swiped, direction);
      setState(() { _dragOffset = Offset.zero; _isDragging = false; });
      _snapController.reset();
    });

    _snapController.addListener(_updateFromAnimation);
  }

  void _animateSnapBack() {
    _snapAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
      .animate(CurvedAnimation(parent: _snapController, curve: Curves.elasticOut));

    _snapController.addListener(_updateFromAnimation);
    _snapController.forward(from: 0).then((_) {
      setState(() { _isDragging = false; _dragOffset = Offset.zero; });
      _snapController.removeListener(_updateFromAnimation);
      _snapController.reset();
    });
  }

  void _updateFromAnimation() {
    if (_snapController.isAnimating) {
      setState(() => _dragOffset = _snapAnimation.value);
    }
  }

  void triggerSwipe(SwipeDirection direction) {
    if (widget.listings.isEmpty) return;
    _animateOffScreen(direction);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listings.isEmpty) return _buildEmptyState();

    final visibleCount = min(_maxVisibleCards, widget.listings.length);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (int i = visibleCount - 1; i > 0; i--) _buildBackCard(i, widget.listings[i]),
        _buildTopCard(widget.listings.first),
      ],
    );
  }

  Widget _buildBackCard(int index, Listing listing) {
    // Next card scales up slightly as top card moves
    final progress = _isDragging ? _swipeProgress : 0.0;
    final scale = 1.0 - (index * 0.05) + (progress * 0.05);
    final opacity = 1.0 - (index * 0.1) + (progress * 0.1);

    return Positioned.fill(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(scale, scale, scale, 1),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: IgnorePointer(
            child: SwipeCard(
              title: listing.title ?? 'Listing',
              subtitle: listing.formattedLocation,
              imageUrl: listing.primaryImage,
              price: listing.formattedPrice,
              tags: listing.quickTags,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard(Listing listing) {
    // Dynamic BoxShadow based on swipe direction
    final shadowOffsetX = (_dragOffset.dx / 10).clamp(-25.0, 25.0);
    final glowColor = _tentativeDirection == SwipeDirection.right 
        ? const Color(0xFF10B981).withAlpha((_swipeProgress * 150).toInt().clamp(0, 255)) // Green
        : _tentativeDirection == SwipeDirection.left
            ? const Color(0xFFEF4444).withAlpha((_swipeProgress * 150).toInt().clamp(0, 255)) // Red
            : Colors.transparent;

    return Positioned.fill(
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: () => widget.onTap?.call(listing),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..setTranslationRaw(_dragOffset.dx, _dragOffset.dy, 0.0)
            ..rotateX(_rotateX)
            ..rotateY(_rotateY)
            ..rotateZ(_rotation)
            // scale down slightly at far edges
            ..scaleByDouble(1.0 - (_swipeProgress * 0.07), 1.0 - (_swipeProgress * 0.07), 1.0 - (_swipeProgress * 0.07), 1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 50,
                  offset: Offset(-shadowOffsetX, 25), // shadow pulls opposite
                ),
                BoxShadow(
                  color: glowColor,
                  blurRadius: 100,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: SwipeCard(
              title: listing.title ?? 'Listing',
              subtitle: listing.formattedLocation,
              imageUrl: listing.primaryImage,
              price: listing.formattedPrice,
              tags: listing.quickTags,
              overlay: Stack(
                children: [
                  // LIKE Stamp
                  if (_tentativeDirection == SwipeDirection.right)
                    Positioned(
                      top: 60, left: 40,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: _SwipeLabel(text: 'LIKE', color: const Color(0xFF10B981), opacity: _swipeProgress),
                      ),
                    ),
                  // NOPE Stamp
                  if (_tentativeDirection == SwipeDirection.left)
                    Positioned(
                      top: 60, right: 40,
                      child: Transform.rotate(
                        angle: 0.2,
                        child: _SwipeLabel(text: 'NOPE', color: const Color(0xFFEF4444), opacity: _swipeProgress),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class _SwipeLabel extends StatelessWidget {
  final String text;
  final Color color;
  final double opacity;

  const _SwipeLabel({required this.text, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    // Scale up as opacity increases (stamp effect)
    final scale = 0.6 + (opacity * 0.6);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 4),
            color: color.withAlpha(40),
          ),
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
