import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/services/app_audio.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/cap_swipe_card.dart';

typedef SwipeCallback = void Function(
  Listing listing,
  SwipeDirection direction,
);

enum SwipeDirection { left, right }

enum _GestureAxis { undecided, horizontal, vertical }

enum _VerticalDirection { previous, next }

/// Shared listing deck used by quick filters and listing discovery.
///
/// Horizontal gestures keep the original like/pass behavior. Vertical gestures
/// are page-locked like Reels/Events: the current listing slides out and the
/// next/previous listing snaps into place. The vertical cursor wraps, so users
/// can keep browsing without hitting an artificial end until they explicitly
/// dismiss cards left/right.
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
  static const _horizontalThreshold = 72.0;
  static const _horizontalVelocity = 900.0;
  static const _verticalVelocity = 650.0;
  static const _axisLockDistance = 8.0;
  static const _maxVisibleCards = 3;
  static const _prefetchCards = 4;

  final _topCardKey = GlobalKey<CapSwipeCardState>();
  final Set<String> _prefetchedImages = <String>{};

  late final AnimationController _horizontalController;
  late final AnimationController _verticalController;
  Animation<Offset>? _horizontalAnimation;
  Animation<double>? _verticalAnimation;

  Offset _dragOffset = Offset.zero;
  Offset _gestureTravel = Offset.zero;
  double _verticalOffset = 0;
  int _cursor = 0;
  bool _isDragging = false;
  bool _zoomLocksDrag = false;
  _GestureAxis _axis = _GestureAxis.undecided;
  _VerticalDirection? _verticalTarget;
  DateTime? _lastWheelAt;

  @override
  void initState() {
    super.initState();
    _horizontalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _verticalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _horizontalController.addListener(_tickHorizontal);
    _verticalController.addListener(_tickVertical);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetchAroundCursor();
  }

  @override
  void didUpdateWidget(covariant SwipeableCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.listings.isEmpty) {
      _cursor = 0;
    } else if (widget.listings.length > oldWidget.listings.length &&
        (oldWidget.listings.isEmpty ||
            widget.listings.first.id != oldWidget.listings.first.id)) {
      // Undo prepends the restored listing; show it immediately.
      _cursor = 0;
    } else if (oldWidget.listings.isNotEmpty) {
      final oldIndex = _cursor.clamp(0, oldWidget.listings.length - 1).toInt();
      final oldId = oldWidget.listings[oldIndex].id;
      final retained = widget.listings.indexWhere((item) => item.id == oldId);
      if (retained >= 0) {
        _cursor = retained;
      } else {
        final oldIds = oldWidget.listings.map((item) => item.id).toSet();
        final overlaps = widget.listings.any((item) => oldIds.contains(item.id));
        if (!overlaps || _cursor >= widget.listings.length) _cursor = 0;
      }
    } else {
      _cursor = 0;
    }

    if (!identical(oldWidget.listings, widget.listings) ||
        oldWidget.listings.length != widget.listings.length) {
      _prefetchAroundCursor();
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  int _normalize(int index) {
    if (widget.listings.isEmpty) return 0;
    return ((index % widget.listings.length) + widget.listings.length) %
        widget.listings.length;
  }

  Listing get _current => widget.listings[_normalize(_cursor)];

  Listing _relative(int delta) => widget.listings[_normalize(_cursor + delta)];

  int _cacheWidth() =>
      (MediaQuery.sizeOf(context).width * 2).round().clamp(480, 1600);

  void _precacheUrl(String raw, int width) {
    final url = raw.trim();
    final uri = Uri.tryParse(url);
    final key = '$width:$url';
    if (url.isEmpty ||
        uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        !_prefetchedImages.add(key)) {
      return;
    }
    final provider = ResizeImage.resizeIfNeeded(width, null, NetworkImage(url));
    unawaited(precacheImage(provider, context).catchError((_) {
      _prefetchedImages.remove(key);
    }));
  }

  void _prefetchAroundCursor() {
    if (!mounted || widget.listings.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.listings.isEmpty) return;
      final width = _cacheWidth();
      final count = min(_prefetchCards, widget.listings.length);
      final indices = <int>{_normalize(_cursor)};
      for (var i = 1; i < count; i++) {
        indices.add(_normalize(_cursor + i));
      }
      if (widget.listings.length > 1) indices.add(_normalize(_cursor - 1));

      for (final index in indices) {
        final images = widget.listings[index].images;
        final active = index == _normalize(_cursor);
        final warmCount = active ? min(12, images.length) : min(2, images.length);
        for (final url in images.take(warmCount)) {
          _precacheUrl(url, width);
        }
        if (active && images.length > 12) {
          for (final url in images.skip(images.length - 2)) {
            _precacheUrl(url, width);
          }
        }
      }
    });
  }

  void _prefetchGalleryNeighbors(int photoIndex) {
    if (!mounted || widget.listings.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.listings.isEmpty) return;
      final images = _current.images;
      if (images.length < 2) return;
      final width = _cacheWidth();
      for (final delta in const [-2, -1, 1, 2, 3]) {
        final index = ((photoIndex + delta) % images.length + images.length) %
            images.length;
        _precacheUrl(images[index], width);
      }
    });
  }

  double get _rotation => (_dragOffset.dx / 400).clamp(-1.0, 1.0) * 0.28;

  double get _horizontalProgress =>
      (_dragOffset.dx.abs() / _horizontalThreshold).clamp(0.0, 1.0);

  double get _likeOpacity {
    if (_dragOffset.dx <= 0) return 0;
    return (_dragOffset.dx / _horizontalThreshold).clamp(0.0, 1.0);
  }

  double get _nopeOpacity {
    if (_dragOffset.dx >= 0) return 0;
    return (-_dragOffset.dx / _horizontalThreshold).clamp(0.0, 1.0);
  }

  bool get _busy =>
      _horizontalController.isAnimating || _verticalController.isAnimating;

  bool get _verticalMode =>
      _axis == _GestureAxis.vertical ||
      _verticalController.isAnimating ||
      _verticalOffset.abs() > 0.5;

  void _resetGesture() {
    _isDragging = false;
    _axis = _GestureAxis.undecided;
    _gestureTravel = Offset.zero;
  }

  void _onPanStart(DragStartDetails details) {
    if (_busy ||
        _zoomLocksDrag ||
        (_topCardKey.currentState?.interceptsDrag ?? false)) {
      return;
    }
    setState(() {
      _isDragging = true;
      _axis = _GestureAxis.undecided;
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
    if (_axis == _GestureAxis.undecided) {
      final dx = _gestureTravel.dx.abs();
      final dy = _gestureTravel.dy.abs();
      if (max(dx, dy) < _axisLockDistance) return;

      if (dy > dx * 1.08 && widget.listings.length > 1) {
        _axis = _GestureAxis.vertical;
        _dragOffset = Offset.zero;
      } else if (dx > dy * 1.08 || widget.listings.length <= 1) {
        _axis = _GestureAxis.horizontal;
        _verticalOffset = 0;
      } else {
        return;
      }
    }

    if (_axis == _GestureAxis.horizontal) {
      setState(() {
        // Intentionally lock Y: the card can only travel left/right when
        // deciding like/pass, so it never feels like a loose free-drag card.
        _dragOffset = Offset(_dragOffset.dx + details.delta.dx, 0);
      });
      return;
    }

    final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
    final limit = max(120.0, height * 0.48);
    setState(() {
      _verticalOffset = (_verticalOffset + details.delta.dy)
          .clamp(-limit, limit)
          .toDouble();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    if (_axis == _GestureAxis.vertical) {
      final velocity = details.velocity.pixelsPerSecond.dy;
      final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
      final threshold = min(110.0, max(64.0, height * 0.14));
      final fling = velocity.abs() > _verticalVelocity;
      if ((_verticalOffset.abs() > threshold || fling) &&
          widget.listings.length > 1) {
        final dy = fling ? velocity : _verticalOffset;
        _animateVertical(
          dy < 0 ? _VerticalDirection.next : _VerticalDirection.previous,
          height,
        );
      } else {
        _snapVerticalBack();
      }
      return;
    }

    if (_axis == _GestureAxis.horizontal) {
      final velocity = details.velocity.pixelsPerSecond.dx;
      final fling = velocity.abs() > _horizontalVelocity;
      if (_dragOffset.dx.abs() > _horizontalThreshold || fling) {
        final dx = fling ? velocity : _dragOffset.dx;
        _animateHorizontal(
          dx >= 0 ? SwipeDirection.right : SwipeDirection.left,
        );
      } else {
        _snapHorizontalBack();
      }
      return;
    }

    setState(_resetGesture);
  }

  void _onPanCancel() {
    if (!_isDragging) return;
    if (_axis == _GestureAxis.vertical && _verticalOffset != 0) {
      _snapVerticalBack();
    } else if (_axis == _GestureAxis.horizontal && _dragOffset != Offset.zero) {
      _snapHorizontalBack();
    } else {
      setState(_resetGesture);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        widget.listings.length < 2 ||
        _busy ||
        _zoomLocksDrag) {
      return;
    }
    final dx = event.scrollDelta.dx.abs();
    final dy = event.scrollDelta.dy.abs();
    if (dy < 8 || dy <= dx) return;

    final now = DateTime.now();
    if (_lastWheelAt != null &&
        now.difference(_lastWheelAt!) < const Duration(milliseconds: 420)) {
      return;
    }
    _lastWheelAt = now;
    final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
    _axis = _GestureAxis.vertical;
    _dragOffset = Offset.zero;
    _verticalOffset = 0;
    _animateVertical(
      event.scrollDelta.dy > 0
          ? _VerticalDirection.next
          : _VerticalDirection.previous,
      height,
    );
  }

  void _animateHorizontal(SwipeDirection direction) {
    if (_busy || widget.listings.isEmpty) return;
    _isDragging = false;
    final width = MediaQuery.sizeOf(context).width;
    final endX = direction == SwipeDirection.right ? width * 1.5 : -width * 1.5;
    _horizontalAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(endX, 0),
    ).animate(
      CurvedAnimation(parent: _horizontalController, curve: Curves.easeOutQuart),
    );
    _horizontalController.forward(from: 0).then((_) {
      if (!mounted || widget.listings.isEmpty) return;
      final swiped = _current;
      direction == SwipeDirection.right
          ? AppHaptics.heavy()
          : AppHaptics.medium();
      unawaited(AppAudio.instance.playSwipeFromPrefs());
      widget.onSwiped(swiped, direction);
      if (!mounted) return;
      setState(() {
        _dragOffset = Offset.zero;
        _resetGesture();
      });
      _horizontalController.reset();
      _prefetchAroundCursor();
    });
  }

  void _snapHorizontalBack() {
    if (_horizontalController.isAnimating) return;
    _isDragging = false;
    _horizontalAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _horizontalController, curve: Curves.easeOutCubic),
    );
    _horizontalController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _dragOffset = Offset.zero;
        _resetGesture();
      });
      _horizontalController.reset();
    });
  }

  void _animateVertical(_VerticalDirection direction, double height) {
    if (_busy || widget.listings.length < 2) return;
    _isDragging = false;
    _verticalTarget = direction;
    _verticalAnimation = Tween<double>(
      begin: _verticalOffset,
      end: direction == _VerticalDirection.next ? -height : height,
    ).animate(
      CurvedAnimation(
        parent: _verticalController,
        curve: const Cubic(0.22, 1, 0.36, 1),
      ),
    );
    _verticalController.forward(from: 0).then((_) {
      if (!mounted || widget.listings.isEmpty) return;
      setState(() {
        _cursor = _normalize(
          _cursor + (direction == _VerticalDirection.next ? 1 : -1),
        );
        _verticalOffset = 0;
        _verticalTarget = null;
        _resetGesture();
      });
      AppHaptics.selection();
      _verticalController.reset();
      _prefetchAroundCursor();
    });
  }

  void _snapVerticalBack() {
    if (_verticalController.isAnimating) return;
    _isDragging = false;
    _verticalTarget = _verticalOffset < 0
        ? _VerticalDirection.next
        : _VerticalDirection.previous;
    _verticalAnimation = Tween<double>(
      begin: _verticalOffset,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _verticalController,
        curve: const Cubic(0.22, 1, 0.36, 1),
      ),
    );
    _verticalController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _verticalOffset = 0;
        _verticalTarget = null;
        _resetGesture();
      });
      _verticalController.reset();
    });
  }

  void _tickHorizontal() {
    final animation = _horizontalAnimation;
    if (mounted && animation != null && _horizontalController.isAnimating) {
      setState(() => _dragOffset = animation.value);
    }
  }

  void _tickVertical() {
    final animation = _verticalAnimation;
    if (mounted && animation != null && _verticalController.isAnimating) {
      setState(() => _verticalOffset = animation.value);
    }
  }

  void triggerSwipe(SwipeDirection direction) {
    if (!_busy && widget.listings.isNotEmpty) _animateHorizontal(direction);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? max(1.0, constraints.maxHeight)
            : max(1.0, MediaQuery.sizeOf(context).height);
        final visibleCount = min(_maxVisibleCards, widget.listings.length);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_verticalMode && widget.listings.length > 1)
              _verticalNeighbor(height)
            else
              for (var i = visibleCount - 1; i > 0; i--)
                _backCard(i, _relative(i)),
            _topCard(_current, height),
          ],
        );
      },
    );
  }

  Widget _backCard(int index, Listing listing) {
    final progress = _isDragging && _axis == _GestureAxis.horizontal
        ? _horizontalProgress
        : 0.0;
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

  Widget _verticalNeighbor(double height) {
    final direction = _verticalTarget ??
        (_verticalOffset <= 0
            ? _VerticalDirection.next
            : _VerticalDirection.previous);
    final listing = direction == _VerticalDirection.next
        ? _relative(1)
        : _relative(-1);
    final startY = direction == _VerticalDirection.next ? height : -height;
    final progress = (_verticalOffset.abs() / height).clamp(0.0, 1.0);

    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, startY + _verticalOffset),
        child: Transform.scale(
          scale: 0.985 + (progress * 0.015),
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CapSwipeCard(
                listing: listing,
                isTop: false,
                railVisible: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topCard(Listing listing, double height) {
    final glow = _dragOffset.dx > 20
        ? const Color(0xFF34D399).withAlpha((_likeOpacity * 140).toInt())
        : _dragOffset.dx < -20
            ? const Color(0xFFFB7185).withAlpha((_nopeOpacity * 140).toInt())
            : Colors.transparent;
    final verticalProgress = (_verticalOffset.abs() / height).clamp(0.0, 1.0);
    final scale = _verticalMode
        ? 1.0 - (verticalProgress * 0.012)
        : 1.0 - (_horizontalProgress * 0.05);
    final translation = _verticalMode
        ? Offset(0, _verticalOffset)
        : Offset(_dragOffset.dx, 0);

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
              ..rotateZ(_verticalMode ? 0 : _rotation)
              ..scaleByDouble(scale, scale, 1, 1),
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
                  onPhotoIndexChanged: _prefetchGalleryNeighbors,
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
