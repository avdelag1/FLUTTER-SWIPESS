import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"

swipe_container_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/screens/client_swipe_container.dart")
swipe_card_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/widgets/swipe_card.dart")
swipeable_card_stack_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart")
action_bar_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/widgets/swipe_action_button_bar.dart")
poker_card_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/widgets/poker_category_card.dart")

# 1. Client Swipe Container
swipe_container_content = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipeable_card_stack.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_action_button_bar.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'dart:ui';

class ClientSwipeContainer extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryTitle;

  const ClientSwipeContainer({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  @override
  ConsumerState<ClientSwipeContainer> createState() => _ClientSwipeContainerState();
}

class _ClientSwipeContainerState extends ConsumerState<ClientSwipeContainer> {
  // Dummy listings for the specific category
  late List<Listing> _listings;
  final GlobalKey<SwipeableCardStackState> _stackKey = GlobalKey<SwipeableCardStackState>();

  @override
  void initState() {
    super.initState();
    _listings = [
      Listing(id: '1', title: '${widget.categoryTitle} Alpha', ownerId: 'owner1', price: 1500000, currency: 'USD', latitude: 0, longitude: 0, primaryImage: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9', status: 'active', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      Listing(id: '2', title: '${widget.categoryTitle} Beta', ownerId: 'owner2', price: 850000, currency: 'USD', latitude: 0, longitude: 0, primaryImage: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a', status: 'active', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      Listing(id: '3', title: '${widget.categoryTitle} Gamma', ownerId: 'owner3', price: 2100000, currency: 'USD', latitude: 0, longitude: 0, primaryImage: 'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a', status: 'active', createdAt: DateTime.now(), updatedAt: DateTime.now()),
    ];
  }

  void _handleLike() {
    _stackKey.currentState?.triggerSwipe(SwipeDirection.right);
  }

  void _handleDislike() {
    _stackKey.currentState?.triggerSwipe(SwipeDirection.left);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Map / Glow
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F172A), // Slate 900
            ),
          ),
          
          // Swipe Deck
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 60, bottom: 0),
                child: SwipeableCardStack(
                  key: _stackKey,
                  listings: _listings,
                  onSwiped: (listing, direction) {
                    setState(() {
                      _listings.remove(listing);
                    });
                  },
                  onTap: (listing) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listingId: listing.id),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Floating Top Rail
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassPillButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(40), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.categoryTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _GlassPillButton(
                  icon: Icons.tune_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Floating Action Bar (Bottom)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: SwipeActionButtonBar(
              onLike: _handleLike,
              onDislike: _handleDislike,
              onUndo: () {},
              onMessage: () {},
              onInsights: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassPillButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 20)),
          ),
        ),
      ),
    );
  }
}
"""

# 2. Swipe Card
swipe_card_content = """import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

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
              errorBuilder: (context, error, stackTrace) => _buildFallbackGradient(),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(50), width: 1),
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
                    Icon(Icons.location_on_rounded, color: Colors.white.withAlpha(200), size: 16),
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
          if (overlay != null) overlay!,
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
"""

# 3. Swipeable Card Stack
swipeable_card_stack_content = """import 'dart:math';
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
      if (direction == SwipeDirection.right) HapticFeedback.heavyImpact();
      else HapticFeedback.mediumImpact();
      
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
        transform: Matrix4.identity()..scaleByDouble(scale),
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
            ..translate(_dragOffset.dx, _dragOffset.dy)
            ..rotateX(_rotateX)
            ..rotateY(_rotateY)
            ..rotateZ(_rotation)
            // scale down slightly at far edges
            ..scaleByDouble(1.0 - (_swipeProgress * 0.07)),
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
"""

# 4. Action Button Bar
action_bar_content = """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeActionButtonBar extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback? onUndo;
  final VoidCallback? onMessage;
  final VoidCallback? onInsights;
  final bool disabled;

  const SwipeActionButtonBar({
    super.key,
    required this.onLike,
    required this.onDislike,
    this.onUndo,
    this.onMessage,
    this.onInsights,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(icon: Icons.undo_rounded, color: const Color(0xFF22C55E), size: 48, iconSize: 22, onTap: onUndo, disabled: disabled),
          _ActionButton(icon: Icons.close_rounded, color: const Color(0xFFEF4444), size: 68, iconSize: 34, onTap: onDislike, disabled: disabled),
          _ActionButton(icon: Icons.chat_bubble_rounded, color: const Color(0xFF3B82F6), size: 48, iconSize: 20, onTap: onMessage, disabled: disabled),
          _ActionButton(icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF5722), size: 68, iconSize: 34, onTap: onLike, disabled: disabled),
          _ActionButton(icon: Icons.remove_red_eye_rounded, color: const Color(0xFF06B6D4), size: 48, iconSize: 22, onTap: onInsights, disabled: disabled),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final bool disabled;

  const _ActionButton({required this.icon, required this.color, required this.size, required this.iconSize, this.onTap, this.disabled = false});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(_) => _controller.forward();
  void _handleTapUp(_) { _controller.reverse(); if (widget.onTap != null) { HapticFeedback.lightImpact(); widget.onTap!(); } }
  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withAlpha(50),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(100),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: widget.color.withAlpha(150), width: 1.5),
          ),
          child: Center(
            child: Icon(widget.icon, size: widget.iconSize, color: widget.color),
          ),
        ),
      ),
    );
  }
}
"""

with open(swipe_container_path, "w") as f:
    f.write(swipe_container_content)
with open(swipe_card_path, "w") as f:
    f.write(swipe_card_content)
with open(swipeable_card_stack_path, "w") as f:
    f.write(swipeable_card_stack_content)
with open(action_bar_path, "w") as f:
    f.write(action_bar_content)

# Now, we need to wire up poker category card to push this new screen on top tap
poker_card_patch = """import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
"""
with open(poker_card_path, "r") as f:
    content = f.read()

content = content.replace("import 'package:flutter_swipes/src/features/swipes/presentation/screens/swiper_screen.dart';", "import 'package:flutter_swipes/src/features/swipes/presentation/screens/swiper_screen.dart';\nimport 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';")
# Change tap behavior in poker card:
# Replace `onTap: () => onBringToFront(index),` with `onTap: () { if (isTop) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientSwipeContainer(categoryId: card.id, categoryTitle: card.title))); } else { onBringToFront(index); } },`
content = content.replace("onTap: () => onBringToFront(index),", "onTap: () { if (isTop) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientSwipeContainer(categoryId: card.id, categoryTitle: card.title))); } else { onBringToFront(index); } },")

# Wait, `isTop` is not accessible in `_buildBackgroundCard` if I just replace it there?
# Actually, the tap happens in `_buildBackgroundCard`. Let's just pass `isTop` or do it correctly:
# `onBringToFront(index)` is only on background cards. The top card is Draggable. We can wrap Draggable content in GestureDetector.
# Let's do this via multi-replace or just replace the whole file. It's safer.
