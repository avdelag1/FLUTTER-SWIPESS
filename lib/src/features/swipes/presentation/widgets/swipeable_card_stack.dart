import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/cap_swipe_card.dart';

typedef SwipeCallback = void Function(
  Listing listing,
  SwipeDirection direction,
);

enum SwipeDirection { left, right }

class SwipeableCardStack extends StatefulWidget {
  const SwipeableCardStack({
    super.key,
    required this.listings,
    required this.onSwiped,
    this.railVisible = true,
    this.onBack,
    this.onInsights,
    this.onShare,
    this.onMessage,
    this.onReport,
    this.onOpenAi,
    this.onOpenMap,
    this.onSummonChrome,
    this.onUndo,
    this.canUndo = false,
  });

  final List<Listing> listings;
  final SwipeCallback onSwiped;
  final bool railVisible;
  final VoidCallback? onBack;
  final void Function(Listing listing)? onInsights;
  final void Function(Listing listing)? onShare;
  final void Function(Listing listing)? onMessage;
  final void Function(Listing listing)? onReport;
  final VoidCallback? onOpenAi;
  final VoidCallback? onOpenMap;
  final VoidCallback? onSummonChrome;
  final VoidCallback? onUndo;
  final bool canUndo;

  @override
  State<SwipeableCardStack> createState() => SwipeableCardStackState();
}

class SwipeableCardStackState extends State<SwipeableCardStack>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _zoomLocksDrag = false;
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  final _topCardKey = GlobalKey<CapSwipeCardState>();
  final Set<String> _prefetchedImages = <String>{};

  static const _swipeThreshold = 72.0;
  static const _velocityThreshold = 900.0;
  static const _maxVisibleCards = 3;
  static const _prefetchCards = 4;
  static const _topGalleryWarmCount = 12;
  static const _backGalleryWarmCount = 2;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetchUpcomingImages();
  }

  @override
  void didUpdateWidget(covariant SwipeableCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.listings, widget.listings) ||
        oldWidget.listings.length != widget.listings.length ||
        (oldWidget.listings.isNotEmpty &&
            widget.listings.isNotEmpty &&
            oldWidget.listings.first.id != widget.listings.first.id)) {
      _prefetchUpcomingImages();
    }
  }

  int _displayCacheWidth() =>
      (MediaQuery.sizeOf(context).width * 2).round().clamp(480, 1600);

  void _precacheListingImage(String rawUrl, int cacheWidth) {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    final cacheKey = '$cacheWidth:$url';
    if (url.isEmpty ||
        uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        !_prefetchedImages.add(cacheKey)) {
      return;
    }

    // Match Image.network(cacheWidth: ...) exactly. Warming an un-resized
    // NetworkImage uses a different cache key and still forces a decode after
    // the user taps to the next photo.
    final provider = ResizeImage.resizeIfNeeded(
      cacheWidth,
      null,
      NetworkImage(url),
    );
    unawaited(
      precacheImage(provider, context).catchError((_) {
        // A failed image should be retryable when the card becomes active.
        _prefetchedImages.remove(cacheKey);
      }),
    );
  }

  void _prefetchUpcomingImages() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cacheWidth = _displayCacheWidth();
      final count = min(_prefetchCards, widget.listings.length);
      for (var i = 0; i < count; i++) {
        final listing = widget.listings[i];
        final images = listing.images;
        if (images.isEmpty) continue;

        if (i == 0) {
          // The active gallery is the interaction hot path. Warm essentially
          // the whole normal gallery, including the last photos so a left tap
          // from photo #1 is instant too.
          if (images.length <= _topGalleryWarmCount) {
            for (final url in images) {
              _precacheListingImage(url, cacheWidth);
            }
          } else {
            for (final url in images.take(_topGalleryWarmCount - 2)) {
              _precacheListingImage(url, cacheWidth);
            }
            for (final url in images.skip(images.length - 2)) {
              _precacheListingImage(url, cacheWidth);
            }
          }
        } else {
          // Back-stack cards need enough media ready to appear immediately but
          // should not consume the same memory budget as the active gallery.
          for (final url in images.take(_backGalleryWarmCount)) {
            _precacheListingImage(url, cacheWidth);
          }
        }
      }
    });
  }

  void _prefetchTopNeighbors(int photoIndex) {
    if (!mounted || widget.listings.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.listings.isEmpty) return;
      final images = widget.listings.first.images;
      if (images.length < 2) return;
      final cacheWidth = _displayCacheWidth();

      // Keep the next/previous neighborhood hot even for unusually large
      // galleries that exceed the initial warm set.
      for (final delta in const [-2, -1, 1, 2, 3]) {
        final index = (photoIndex + delta) % images.length;
        _precacheListingImage(images[index], cacheWidth);
      }
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double get _rotation => (_dragOffset.dx / 400).clamp(-1.0, 1.0) * 0.28;

  double get _swipeProgress =>
      (_dragOffset.dx.abs() / _swipeThreshold).clamp(0.0, 1.0);

  double get _likeOpacity {
    final dx = _dragOffset.dx;
    if (dx <= 0) return 0;
    if (dx >= _swipeThreshold) return 1;
    final halfway = _swipeThreshold / 2;
    if (dx < halfway) return (dx / halfway) * 0.5;
    return 0.5 + ((dx - halfway) / halfway) * 0.5;
  }

  double get _nopeOpacity {
    final dx = _dragOffset.dx;
    if (dx >= 0) return 0;
    final a = -dx;
    if (a >= _swipeThreshold) return 1;
    final halfway = _swipeThreshold / 2;
    if (a < halfway) return (a / halfway) * 0.5;
    return 0.5 + ((a - halfway) / halfway) * 0.5;
  }

  void _onPanStart(DragStartDetails details) {
    if (_snapController.isAnimating ||
        _zoomLocksDrag ||
        (_topCardKey.currentState?.interceptsDrag ?? false)) {
      return;
    }
    _snapController.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging ||
        _zoomLocksDrag ||
        (_topCardKey.currentState?.interceptsDrag ?? false)) {
      return;
    }
    setState(() => _dragOffset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final fling = velocity.abs() > _velocityThreshold;
    final shouldSwipe = _dragOffset.dx.abs() > _swipeThreshold || fling;

    if (shouldSwipe && widget.listings.isNotEmpty) {
      final directionalDx = fling ? velocity : _dragOffset.dx;
      final direction = directionalDx >= 0
          ? SwipeDirection.right
          : SwipeDirection.left;
      _animateOffScreen(direction);
    } else {
      _animateSnapBack();
    }
  }

  void _animateOffScreen(SwipeDirection direction) {
    if (_snapController.isAnimating || widget.listings.isEmpty) return;
    _isDragging = false;
    final screenWidth = MediaQuery.of(context).size.width;
    final endX = direction == SwipeDirection.right
        ? screenWidth * 1.5
        : -screenWidth * 1.5;

    _snapAnimation =
        Tween<Offset>(
          begin: _dragOffset,
          end: Offset(endX, _dragOffset.dy),
        ).animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutQuart),
        );

    _snapController.addListener(_updateFromAnimation);
    _snapController.forward(from: 0).then((_) {
      if (!mounted) return;
      if (direction == SwipeDirection.right) {
        AppHaptics.heavy();
      } else {
        AppHaptics.medium();
      }
      final swiped = widget.listings.first;
      widget.onSwiped(swiped, direction);
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
      _snapController.removeListener(_updateFromAnimation);
      _snapController.reset();
      _prefetchUpcomingImages();
    });
  }

  void _animateSnapBack() {
    if (_snapController.isAnimating) return;
    _isDragging = false;
    _snapAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
        );
    _snapController.addListener(_updateFromAnimation);
    _snapController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _isDragging = false;
        _dragOffset = Offset.zero;
      });
      _snapController.removeListener(_updateFromAnimation);
      _snapController.reset();
    });
  }

  void _updateFromAnimation() {
    if (_snapController.isAnimating && mounted) {
      setState(() => _dragOffset = _snapAnimation.value);
    }
  }

  void triggerSwipe(SwipeDirection direction) {
    if (widget.listings.isEmpty || _snapController.isAnimating) return;
    _animateOffScreen(direction);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listings.isEmpty) {
      return const Center(
        child: Text(
          "You've seen all listings in this category!",
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final visibleCount = min(_maxVisibleCards, widget.listings.length);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (var i = visibleCount - 1; i > 0; i--)
          _buildBackCard(i, widget.listings[i]),
        _buildTopCard(widget.listings.first),
      ],
    );
  }

  Widget _buildBackCard(int index, Listing listing) {
    final progress = _isDragging ? _swipeProgress : 0.0;
    final scale = 1.0 - (index * 0.04) + (progress * 0.04);
    return Positioned.fill(
      child: Transform.scale(
        scale: scale,
        child: IgnorePointer(
          child: CapSwipeCard(
            listing: listing,
            isTop: false,
            railVisible: false,
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard(Listing listing) {
    final glow = _dragOffset.dx > 20
        ? const Color(0xFF34D399).withAlpha((_likeOpacity * 140).toInt())
        : _dragOffset.dx < -20
        ? const Color(0xFFFB7185).withAlpha((_nopeOpacity * 140).toInt())
        : Colors.transparent;

    return Positioned.fill(
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..setTranslationRaw(_dragOffset.dx, _dragOffset.dy, 0)
            ..rotateZ(_rotation)
            ..scaleByDouble(
              1.0 - (_swipeProgress * 0.05),
              1.0 - (_swipeProgress * 0.05),
              1,
              1,
            ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(140),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(color: glow, blurRadius: 80, spreadRadius: 4),
              ],
            ),
            child: RepaintBoundary(
              child: CapSwipeCard(
                key: _topCardKey,
                listing: listing,
                isTop: true,
                likeOpacity: _likeOpacity,
                nopeOpacity: _nopeOpacity,
                railVisible: widget.railVisible,
                canUndo: widget.canUndo,
                onBack: widget.onBack,
                onUndo: widget.onUndo,
                onInsights: () => widget.onInsights?.call(listing),
                onShare: () => widget.onShare?.call(listing),
                onMessage: () => widget.onMessage?.call(listing),
                onReport: () => widget.onReport?.call(listing),
                onOpenAi: widget.onOpenAi,
                onOpenMap: widget.onOpenMap,
                onSummonChrome: widget.onSummonChrome,
                onPhotoIndexChanged: _prefetchTopNeighbors,
                onZoomChanged: (active) {
                  if (mounted) setState(() => _zoomLocksDrag = active);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
