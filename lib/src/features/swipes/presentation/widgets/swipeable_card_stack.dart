import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/services/app_audio.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/cap_swipe_card.dart';

typedef SwipeCallback = void Function(
  Listing listing,
  SwipeDirection direction,
);

enum SwipeDirection { left, right }

enum _GestureAxis { undecided, horizontal, vertical }

enum _VerticalBrowseDirection { previous, next }

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
    with TickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  double _verticalOffset = 0;
  bool _isDragging = false;
  bool _zoomLocksDrag = false;
  _GestureAxis _gestureAxis = _GestureAxis.undecided;
  Offset _gestureTravel = Offset.zero;
  int _cursor = 0;
  DateTime? _lastPointerScrollAt;

  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;
  late AnimationController _verticalController;
  late Animation<double> _verticalAnimation;
  _VerticalBrowseDirection? _verticalTarget;

  final _topCardKey = GlobalKey<CapSwipeCardState>();
  final Set<String> _prefetchedImages = <String>{};

  static const _swipeThreshold = 72.0;
  static const _velocityThreshold = 900.0;
  static const _verticalVelocityThreshold = 650.0;
  static const _axisLockDistance = 8.0;
  static const _maxVisibleCards = 3;
  static const _nextCardRiseDistance = 56.0;
  static const _nextCardRestScale = 0.925;
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
    _verticalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
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

    if (widget.listings.isEmpty) {
      _cursor = 0;
    } else if (widget.listings.length > oldWidget.listings.length &&
        (oldWidget.listings.isEmpty ||
            widget.listings.first.id != oldWidget.listings.first.id)) {
      // Undo puts the restored listing back at the front. Keep the old
      // behavior where undo immediately brings that card back into view.
      _cursor = 0;
    } else if (oldWidget.listings.isNotEmpty) {
      final oldIndex = _cursor.clamp(0, oldWidget.listings.length - 1).toInt();
      final oldCurrentId = oldWidget.listings[oldIndex].id;
      final sameCardIndex = widget.listings.indexWhere(
        (listing) => listing.id == oldCurrentId,
      );
      if (sameCardIndex >= 0) {
        _cursor = sameCardIndex;
      } else {
        final oldIds = oldWidget.listings.map((listing) => listing.id).toSet();
        final hasAnyOverlap = widget.listings.any(
          (listing) => oldIds.contains(listing.id),
        );
        if (!hasAnyOverlap || _cursor >= widget.listings.length) {
          _cursor = 0;
        }
      }
    } else {
      _cursor = 0;
    }

    if (!identical(oldWidget.listings, widget.listings) ||
        oldWidget.listings.length != widget.listings.length ||
        (oldWidget.listings.isNotEmpty &&
            widget.listings.isNotEmpty &&
            oldWidget.listings.first.id != widget.listings.first.id)) {
      _prefetchUpcomingImages();
    }
  }

  int _normalizeIndex(int index) {
    final length = widget.listings.length;
    if (length == 0) return 0;
    return ((index % length) + length) % length;
  }

  Listing get _currentListing => widget.listings[_normalizeIndex(_cursor)];

  Listing _listingAtOffset(int offset) {
    return widget.listings[_normalizeIndex(_cursor + offset)];
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
    if (!mounted || widget.listings.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.listings.isEmpty) return;
      final cacheWidth = _displayCacheWidth();
      final count = min(_prefetchCards, widget.listings.length);
      final indices = <int>{_normalizeIndex(_cursor)};

      // Warm the forward reel plus one previous card so either vertical
      // direction feels immediate and the deck can loop forever.
      for (var offset = 1; offset < count; offset++) {
        indices.add(_normalizeIndex(_cursor + offset));
      }
      if (widget.listings.length > 1) {
        indices.add(_normalizeIndex(_cursor - 1));
      }

      for (final index in indices) {
        final listing = widget.listings[index];
        final images = listing.images;
        if (images.isEmpty) continue;
        final isActive = index == _normalizeIndex(_cursor);

        if (isActive) {
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
          // Neighbor cards need enough media ready to enter instantly but
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
      final images = _currentListing.images;
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
    _verticalController.dispose();
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

  bool get _verticalMode =>
      _gestureAxis == _GestureAxis.vertical ||
      _verticalController.isAnimating ||
      _verticalOffset.abs() > 0.5;

  void _resetGesture() {
    _isDragging = false;
    _gestureAxis = _GestureAxis.undecided;
    _gestureTravel = Offset.zero;
  }

  void _onPanStart(DragStartDetails details) {
    if (_snapController.isAnimating ||
        _verticalController.isAnimating ||
        _zoomLocksDrag ||
        (_topCardKey.currentState?.interceptsDrag ?? false)) {
      return;
    }
    _snapController.stop();
    _verticalController.stop();
    setState(() {
      _isDragging = true;
      _gestureAxis = _GestureAxis.undecided;
      _gestureTravel = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging ||
        _zoomLocksDrag ||
        (_topCardKey.currentState?.interceptsDrag ?? false)) {
      return;
    }

    _gestureTravel += details.delta;

    if (_gestureAxis == _GestureAxis.undecided) {
      final dx = _gestureTravel.dx.abs();
      final dy = _gestureTravel.dy.abs();
      if (max(dx, dy) < _axisLockDistance) return;

      // Once direction is clear, lock it for the full gesture. Horizontal
      // swipes can no longer drift diagonally; vertical motion becomes a
      // reels-style page change instead of physically dragging the card free.
      if (dy > dx * 1.08 && widget.listings.length > 1) {
        _gestureAxis = _GestureAxis.vertical;
        _dragOffset = Offset.zero;
      } else if (dx > dy * 1.08 || widget.listings.length <= 1) {
        _gestureAxis = _GestureAxis.horizontal;
        _verticalOffset = 0;
      } else {
        return;
      }
    }

    if (_gestureAxis == _GestureAxis.horizontal) {
      setState(() {
        _dragOffset = Offset(_dragOffset.dx + details.delta.dx, 0);
      });
      return;
    }

    final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
    final maxTravel = max(120.0, height * 0.48);
    setState(() {
      _verticalOffset = (_verticalOffset + details.delta.dy)
          .clamp(-maxTravel, maxTravel)
          .toDouble();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    if (_gestureAxis == _GestureAxis.vertical) {
      final velocity = details.velocity.pixelsPerSecond.dy;
      final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
      final threshold = min(110.0, max(64.0, height * 0.14));
      final fling = velocity.abs() > _verticalVelocityThreshold;
      final shouldMove = _verticalOffset.abs() > threshold || fling;

      if (shouldMove && widget.listings.length > 1) {
        final directionalDy = fling ? velocity : _verticalOffset;
        _animateVerticalPage(
          directionalDy < 0
              ? _VerticalBrowseDirection.next
              : _VerticalBrowseDirection.previous,
        );
      } else {
        _animateVerticalSnapBack();
      }
      return;
    }

    if (_gestureAxis == _GestureAxis.horizontal) {
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
      return;
    }

    setState(_resetGesture);
  }

  void _onPanCancel() {
    if (!_isDragging) return;
    if (_gestureAxis == _GestureAxis.vertical && _verticalOffset != 0) {
      _animateVerticalSnapBack();
    } else if (_gestureAxis == _GestureAxis.horizontal &&
        _dragOffset != Offset.zero) {
      _animateSnapBack();
    } else {
      setState(_resetGesture);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        widget.listings.length < 2 ||
        _snapController.isAnimating ||
        _verticalController.isAnimating ||
        _zoomLocksDrag) {
      return;
    }

    final dx = event.scrollDelta.dx.abs();
    final dy = event.scrollDelta.dy.abs();
    if (dy < 8 || dy <= dx) return;

    final now = DateTime.now();
    final last = _lastPointerScrollAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 420)) {
      return;
    }
    _lastPointerScrollAt = now;
    _gestureAxis = _GestureAxis.vertical;
    _gestureTravel = Offset.zero;
    _dragOffset = Offset.zero;
    _verticalOffset = 0;
    _animateVerticalPage(
      event.scrollDelta.dy > 0
          ? _VerticalBrowseDirection.next
          : _VerticalBrowseDirection.previous,
    );
  }

  void _animateOffScreen(SwipeDirection direction) {
    if (_snapController.isAnimating || widget.listings.isEmpty) return;
    _isDragging = false;
    final screenWidth = MediaQuery.of(context).size.width;
    final endX = direction == SwipeDirection.right
        ? screenWidth * 1.5
        : -screenWidth * 1.5;

    _snapAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(endX, 0),
    ).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutQuart),
    );

    _snapController.addListener(_updateFromAnimation);
    _snapController.forward(from: 0).then((_) {
      if (!mounted || widget.listings.isEmpty) return;
      if (direction == SwipeDirection.right) {
        AppHaptics.heavy();
      } else {
        AppHaptics.medium();
      }
      unawaited(AppAudio.instance.playSwipeFromPrefs());
      final swiped = _currentListing;
      widget.onSwiped(swiped, direction);
      if (!mounted) return;
      setState(() {
        _dragOffset = Offset.zero;
        _resetGesture();
      });
      _snapController.removeListener(_updateFromAnimation);
      _snapController.reset();
      _prefetchUpcomingImages();
    });
  }

  void _animateSnapBack() {
    if (_snapController.isAnimating) return;
    _isDragging = false;
    _snapAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    _snapController.addListener(_updateFromAnimation);
    _snapController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _dragOffset = Offset.zero;
        _resetGesture();
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

  void _animateVerticalPage(_VerticalBrowseDirection direction) {
    if (_verticalController.isAnimating || widget.listings.length < 2) return;
    _isDragging = false;
    _verticalTarget = direction;
    final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
    final endY = direction == _VerticalBrowseDirection.next ? -height : height;

    _verticalAnimation = Tween<double>(
      begin: _verticalOffset,
      end: endY,
    ).animate(
      CurvedAnimation(
        parent: _verticalController,
        curve: const Cubic(0.22, 1, 0.36, 1),
      ),
    );

    _verticalController.addListener(_updateVerticalAnimation);
    _verticalController.forward(from: 0).then((_) {
      if (!mounted || widget.listings.isEmpty) return;
      setState(() {
        _cursor = _normalizeIndex(
          _cursor + (direction == _VerticalBrowseDirection.next ? 1 : -1),
        );
        _verticalOffset = 0;
        _verticalTarget = null;
        _resetGesture();
      });
      AppHaptics.selection();
      _verticalController.removeListener(_updateVerticalAnimation);
      _verticalController.reset();
      _prefetchUpcomingImages();
    });
  }

  void _animateVerticalSnapBack() {
    if (_verticalController.isAnimating) return;
    _isDragging = false;
    _verticalTarget = _verticalOffset < 0
        ? _VerticalBrowseDirection.next
        : _VerticalBrowseDirection.previous;
    _verticalAnimation = Tween<double>(
      begin: _verticalOffset,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _verticalController,
        curve: const Cubic(0.22, 1, 0.36, 1),
      ),
    );

    _verticalController.addListener(_updateVerticalAnimation);
    _verticalController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _verticalOffset = 0;
        _verticalTarget = null;
        _resetGesture();
      });
      _verticalController.removeListener(_updateVerticalAnimation);
      _verticalController.reset();
    });
  }

  void _updateVerticalAnimation() {
    if (_verticalController.isAnimating && mounted) {
      setState(() => _verticalOffset = _verticalAnimation.value);
    }
  }

  void triggerSwipe(SwipeDirection direction) {
    if (widget.listings.isEmpty ||
        _snapController.isAnimating ||
        _verticalController.isAnimating) {
      return;
    }
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
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          if (_verticalMode && widget.listings.length > 1)
            _buildVerticalNeighbor()
          else
            for (var i = visibleCount - 1; i > 0; i--)
              _buildBackCard(i, _listingAtOffset(i)),
          _buildTopCard(_currentListing),
        ],
      ),
    );
  }

  bool get _horizontalSwipeActive =>
      _snapController.isAnimating ||
      (_isDragging && _gestureAxis == _GestureAxis.horizontal);

  double _backCardRiseProgress(int index) {
    if (!_horizontalSwipeActive) return 0.0;
    if (index == 1) {
      return Curves.easeOutCubic.transform(_swipeProgress);
    }
    return _swipeProgress * 0.55;
  }

  ({double scale, double translateY}) _backCardTransform(int index) {
    final rise = _backCardRiseProgress(index);
    if (index == 1) {
      final scale = _nextCardRestScale + ((1.0 - _nextCardRestScale) * rise);
      final translateY = _nextCardRiseDistance * (1.0 - rise);
      return (scale: scale, translateY: translateY);
    }

    final depthScale = 1.0 - (index * 0.045);
    final scale = depthScale + (rise * 0.03);
    final translateY = (index * 18.0) * (1.0 - rise);
    return (scale: scale, translateY: translateY);
  }

  Widget _buildBackCard(int index, Listing listing) {
    final transform = _backCardTransform(index);
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, transform.translateY),
        child: Transform.scale(
          scale: transform.scale,
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: CapSwipeCard(
              listing: listing,
              isTop: false,
              railVisible: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalNeighbor() {
    final height = max(
      1.0,
      context.size?.height ?? MediaQuery.sizeOf(context).height,
    );
    final direction = _verticalTarget ??
        (_verticalOffset <= 0
            ? _VerticalBrowseDirection.next
            : _VerticalBrowseDirection.previous);
    final neighbor = direction == _VerticalBrowseDirection.next
        ? _listingAtOffset(1)
        : _listingAtOffset(-1);
    final startY = direction == _VerticalBrowseDirection.next ? height : -height;
    final y = startY + _verticalOffset;
    final progress =
        (_verticalOffset.abs() / height).clamp(0.0, 1.0).toDouble();
    final scale = 0.985 + (progress * 0.015);

    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, y),
        child: Transform.scale(
          scale: scale,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CapSwipeCard(
                listing: neighbor,
                isTop: false,
                railVisible: false,
              ),
            ),
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
    final height = max(
      1.0,
      context.size?.height ?? MediaQuery.sizeOf(context).height,
    );
    final verticalProgress =
        (_verticalOffset.abs() / height).clamp(0.0, 1.0).toDouble();
    final topScale = _verticalMode
        ? 1.0 - (verticalProgress * 0.012)
        : 1.0 - (_swipeProgress * 0.05);
    final translation = _verticalMode
        ? Offset(0, _verticalOffset)
        : Offset(_dragOffset.dx, 0);
    final rotation = _verticalMode ? 0.0 : _rotation;

    return Positioned.fill(
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..setTranslationRaw(translation.dx, translation.dy, 0)
              ..rotateZ(rotation)
              ..scaleByDouble(topScale, topScale, 1, 1),
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
      ),
    );
  }
}
