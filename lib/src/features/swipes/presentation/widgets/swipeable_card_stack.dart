import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_swipes/src/core/services/app_audio.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/cap_swipe_card.dart';
import 'package:video_player/video_player.dart';

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
  static const _nextCardRiseDistance = 56.0;
  static const _nextCardRestScale = 0.925;
  static const _prefetchCards = 6;
  static const _videoPreloadAhead = 2;
  static const _videoPreloadBehind = 1;
  static const _hapticBands = [0.25, 0.50, 0.75];
  static const _verticalSpring = SpringDescription(
    mass: 0.48,
    stiffness: 620,
    damping: 34,
  );
  static const _horizontalSnapSpring = SpringDescription(
    mass: 0.65,
    stiffness: 480,
    damping: 30,
  );

  final Set<String> _prefetchedImages = <String>{};
  final Map<String, VideoPlayerController> _preloadedVideos =
      <String, VideoPlayerController>{};

  late final AnimationController _horizontalController;
  late final AnimationController _verticalController;
  Animation<Offset>? _horizontalAnimation;

  Offset _dragOffset = Offset.zero;
  Offset _gestureTravel = Offset.zero;
  double _verticalOffset = 0;
  int _cursor = 0;
  int _hapticBandMask = 0;
  bool _isDragging = false;
  bool _zoomLocksDrag = false;
  bool _horizontalSpringSnap = false;
  bool _verticalSpringSnap = false;
  bool _dragArmed = false;
  int? _activePointer;
  VelocityTracker? _velocityTracker;
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
    // Vertical paging is expressed in physical pixels, not 0..1 progress.
    // A bounded controller clamps those values and creates the visible pause
    // before the next card suddenly appears. Keep the spring fully unbounded.
    _verticalController = AnimationController.unbounded(vsync: this);
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
        final overlaps = widget.listings.any(
          (item) => oldIds.contains(item.id),
        );
        if (!overlaps || _cursor >= widget.listings.length) _cursor = 0;
      }
    } else {
      _cursor = 0;
    }

    if (!identical(oldWidget.listings, widget.listings) ||
        oldWidget.listings.length != widget.listings.length) {
      _prefetchAroundCursor();
      _preloadListingVideos();
    }
  }

  @override
  void dispose() {
    for (final player in _preloadedVideos.values) {
      player.dispose();
    }
    _preloadedVideos.clear();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  bool _isVideoUrl(String value) {
    final l = value.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('/videos/');
  }

  String? _listingPrimaryVideo(Listing listing) {
    final media = <String>[...listing.images];
    final video = listing.videoUrl?.trim();
    if (video != null && video.isNotEmpty && !media.contains(video)) {
      media.add(video);
    }
    for (final url in media) {
      if (_isVideoUrl(url)) return url;
    }
    return null;
  }

  void _consumePreparedVideo(String listingId) {
    _preloadedVideos.remove(listingId);
    _preloadListingVideos();
  }

  void _preloadListingVideos() {
    if (!mounted || widget.listings.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmListingVideos());
    });
  }

  String? _listingHeroImage(Listing listing) {
    for (final raw in listing.images) {
      final url = raw.trim();
      if (url.isNotEmpty && !_isVideoUrl(url)) return url;
    }
    return listing.images.isNotEmpty ? listing.images.first.trim() : null;
  }

  Future<void> _warmListingVideos() async {
    if (!mounted || widget.listings.isEmpty) return;

    final keep = <String>{};
    for (
      var delta = -_videoPreloadBehind;
      delta <= _videoPreloadAhead;
      delta++
    ) {
      if (delta == 0) continue;
      if (widget.listings.length <= 1) break;
      final listing = _relative(delta);
      keep.add(listing.id);
      if (_preloadedVideos.containsKey(listing.id)) continue;

      final url = _listingPrimaryVideo(listing);
      if (url == null) continue;

      final player = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await player.initialize();
        await player.setLooping(true);
        await player.setVolume(0);
        if (!mounted) {
          await player.dispose();
          return;
        }
        if (_relative(delta).id != listing.id) {
          await player.dispose();
          continue;
        }
        _preloadedVideos[listing.id] = player;
        await player.play();
      } catch (_) {
        await player.dispose();
      }
    }

    for (final id in _preloadedVideos.keys.toList()) {
      if (!keep.contains(id)) {
        _preloadedVideos.remove(id)?.dispose();
      }
    }
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
    unawaited(
      precacheImage(provider, context).catchError((_) {
        _prefetchedImages.remove(key);
      }),
    );
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
      if (widget.listings.length > 1) {
        indices.add(_normalize(_cursor - 1));
        indices.add(_normalize(_cursor - 2));
      }

      for (final index in indices) {
        final listing = widget.listings[index];
        final hero = _listingHeroImage(listing);
        if (hero != null) _precacheUrl(hero, width);

        final images = listing.images;
        final active = index == _normalize(_cursor);
        final warmCount = active
            ? min(12, images.length)
            : min(3, images.length);
        for (final url in images.take(warmCount)) {
          _precacheUrl(url, width);
        }
        if (active && images.length > 12) {
          for (final url in images.skip(images.length - 2)) {
            _precacheUrl(url, width);
          }
        }
      }
      _preloadListingVideos();
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
        final index =
            ((photoIndex + delta) % images.length + images.length) %
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
    _dragArmed = false;
    _activePointer = null;
    _axis = _GestureAxis.undecided;
    _gestureTravel = Offset.zero;
    _hapticBandMask = 0;
  }

  void _maybePulseHorizontalHaptics() {
    final progress = _horizontalProgress;
    for (var i = 0; i < _hapticBands.length; i++) {
      final bit = 1 << i;
      if (progress >= _hapticBands[i] && (_hapticBandMask & bit) == 0) {
        _hapticBandMask |= bit;
        unawaited(AppHaptics.selection());
      }
    }
  }

  void _lockAxis() {
    final dx = _gestureTravel.dx.abs();
    final dy = _gestureTravel.dy.abs();
    if (widget.listings.length > 1 && dy > dx * 1.08) {
      _axis = _GestureAxis.vertical;
      _dragOffset = Offset.zero;
      _verticalOffset = _gestureTravel.dy;
      _verticalTarget = _gestureTravel.dy <= 0
          ? _VerticalDirection.next
          : _VerticalDirection.previous;
      return;
    }
    _axis = _GestureAxis.horizontal;
    _verticalOffset = 0;
    _verticalTarget = null;
    _dragOffset = Offset(_gestureTravel.dx, 0);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_zoomLocksDrag) {
      return;
    }
    if (_busy) {
      _horizontalController.stop();
      _verticalController.stop();
      _horizontalSpringSnap = false;
      _verticalSpringSnap = false;
      _verticalController.value = 0;
    }
    _activePointer = event.pointer;
    _dragArmed = true;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
    setState(() {
      _isDragging = false;
      _axis = _GestureAxis.undecided;
      _gestureTravel = Offset.zero;
      _dragOffset = Offset.zero;
      _verticalOffset = 0;
      _verticalTarget = null;
      _hapticBandMask = 0;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_dragArmed || _activePointer != event.pointer || _zoomLocksDrag) {
      return;
    }
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final delta = event.delta;
    _gestureTravel += delta;
    final dx = _gestureTravel.dx.abs();
    final dy = _gestureTravel.dy.abs();

    if (!_isDragging) {
      if (max(dx, dy) < _axisLockDistance) return;
      setState(() => _isDragging = true);
      _lockAxis();
    } else if (_axis == _GestureAxis.undecided) {
      _lockAxis();
    }

    if (_axis == _GestureAxis.horizontal) {
      setState(() {
        _dragOffset = Offset(_gestureTravel.dx, 0);
      });
      _maybePulseHorizontalHaptics();
      return;
    }

    if (_axis != _GestureAxis.vertical) return;

    final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
    setState(() {
      _verticalOffset = _gestureTravel.dy.clamp(-height, height).toDouble();
      _verticalTarget = _gestureTravel.dy <= 0
          ? _VerticalDirection.next
          : _VerticalDirection.previous;
    });
  }

  void _finishPointerDrag() {
    if (!_dragArmed) return;
    _dragArmed = false;
    _activePointer = null;

    if (!_isDragging) {
      setState(_resetGesture);
      return;
    }

    final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;

    if (_axis == _GestureAxis.undecided) {
      final dx = _gestureTravel.dx.abs();
      final dy = _gestureTravel.dy.abs();
      if (dx >= dy) {
        _axis = _GestureAxis.horizontal;
        _dragOffset = Offset(_gestureTravel.dx, 0);
        _onPanEnd(DragEndDetails(velocity: velocity));
      } else if (widget.listings.length > 1) {
        _axis = _GestureAxis.vertical;
        _verticalOffset = _gestureTravel.dy;
        _onPanEnd(DragEndDetails(velocity: velocity));
      } else {
        setState(_resetGesture);
      }
      return;
    }

    _onPanEnd(DragEndDetails(velocity: velocity));
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _finishPointerDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _finishPointerDrag();
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    if (_axis == _GestureAxis.vertical) {
      final velocity = details.velocity.pixelsPerSecond.dy;
      final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
      // Reel paging should commit with a deliberate short pull, while a
      // quick flick commits primarily from velocity. Requiring half the card
      // made touch paging feel heavy and unlike Events/Reels.
      final threshold = min(140.0, max(72.0, height * 0.18));
      final fling = velocity.abs() > _verticalVelocity;
      if ((_verticalOffset.abs() > threshold || fling) &&
          widget.listings.length > 1) {
        final dy = fling ? velocity : _verticalOffset;
        _animateVertical(
          dy < 0 ? _VerticalDirection.next : _VerticalDirection.previous,
          height,
          velocity,
        );
      } else {
        _snapVerticalBack(velocity);
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
        _snapHorizontalBack(velocity);
      }
      return;
    }

    setState(_resetGesture);
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
    _horizontalSpringSnap = false;
    final width = MediaQuery.sizeOf(context).width;
    final endX = direction == SwipeDirection.right ? width * 1.5 : -width * 1.5;
    _horizontalAnimation =
        Tween<Offset>(begin: _dragOffset, end: Offset(endX, 0)).animate(
          CurvedAnimation(
            parent: _horizontalController,
            curve: Curves.easeOutQuart,
          ),
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
      _preloadListingVideos();
    });
  }

  void _snapHorizontalBack([double velocity = 0]) {
    if (_horizontalController.isAnimating) return;
    _isDragging = false;
    _horizontalSpringSnap = true;
    _horizontalAnimation = null;
    final simulation = SpringSimulation(
      _horizontalSnapSpring,
      _dragOffset.dx,
      0,
      velocity,
    );
    _horizontalController.animateWith(simulation).then((_) {
      if (!mounted) return;
      setState(() {
        _dragOffset = Offset.zero;
        _resetGesture();
      });
      _horizontalSpringSnap = false;
      _horizontalController.reset();
    });
  }

  void _animateVertical(
    _VerticalDirection direction,
    double height, [
    double velocity = 0,
  ]) {
    if (_busy || widget.listings.length < 2) return;
    _isDragging = false;
    _verticalTarget = direction;
    _verticalSpringSnap = true;

    final end = direction == _VerticalDirection.next ? -height : height;
    final carriedVelocity = velocity.clamp(-5200.0, 5200.0).toDouble();

    // Keep the incoming listing already painted while the current card exits.
    // The unbounded controller now follows this pixel spring every frame, so a
    // fast flick never waits off-screen and then swaps the listing afterward.
    final simulation = SpringSimulation(
      _verticalSpring,
      _verticalOffset,
      end,
      carriedVelocity,
    );
    _verticalController.animateWith(simulation).then((_) {
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
      _verticalSpringSnap = false;
      _verticalController.stop();
      _verticalController.value = 0;
      _prefetchAroundCursor();
      _preloadListingVideos();
    });
  }

  void _snapVerticalBack([double velocity = 0]) {
    if (_verticalController.isAnimating) return;
    _isDragging = false;
    _verticalTarget = _verticalOffset < 0
        ? _VerticalDirection.next
        : _VerticalDirection.previous;
    _verticalSpringSnap = true;
    final carriedVelocity = velocity.clamp(-4200.0, 4200.0).toDouble();
    final simulation = SpringSimulation(
      _verticalSpring,
      _verticalOffset,
      0,
      carriedVelocity,
    );
    _verticalController.animateWith(simulation).then((_) {
      if (!mounted) return;
      setState(() {
        _verticalOffset = 0;
        _verticalTarget = null;
        _resetGesture();
      });
      _verticalSpringSnap = false;
      _verticalController.stop();
      _verticalController.value = 0;
    });
  }

  void _tickHorizontal() {
    if (!mounted || !_horizontalController.isAnimating) return;
    if (_horizontalSpringSnap) {
      setState(() => _dragOffset = Offset(_horizontalController.value, 0));
      return;
    }
    final animation = _horizontalAnimation;
    if (animation != null) {
      setState(() => _dragOffset = animation.value);
    }
  }

  void _tickVertical() {
    if (mounted && _verticalController.isAnimating && _verticalSpringSnap) {
      setState(() => _verticalOffset = _verticalController.value);
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
        return ClipRect(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: [
              if (widget.listings.length > 1 && !_showHorizontalStack) ...[
                _verticalSlot(height, _relative(1), height + _verticalOffset),
                _verticalSlot(height, _relative(-1), -height + _verticalOffset),
              ] else if (_showHorizontalStack)
                for (var i = visibleCount - 1; i > 0; i--)
                  _backCard(i, _relative(i)),
              _topCard(_current, height),
            ],
          ),
        );
      },
    );
  }

  bool get _horizontalSwipeActive =>
      _horizontalController.isAnimating ||
      (_isDragging && _axis == _GestureAxis.horizontal);

  bool get _verticalPagingActive =>
      _verticalMode ||
      (_isDragging &&
          widget.listings.length > 1 &&
          (_axis == _GestureAxis.vertical ||
              (_axis == _GestureAxis.undecided &&
                  _gestureTravel.dy.abs() > _gestureTravel.dx.abs() * 1.05)));

  bool get _showHorizontalStack =>
      _horizontalSwipeActive && !_verticalPagingActive;

  double _backCardRiseProgress(int index) {
    if (!_horizontalSwipeActive) return 0.0;
    if (index == 1) {
      return Curves.easeOutCubic.transform(_horizontalProgress);
    }
    return _horizontalProgress * 0.55;
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

  Widget _backCard(int index, Listing listing) {
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

  Widget _verticalSlot(double height, Listing listing, double yOffset) {
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, yOffset),
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CapSwipeCard(
              key: ValueKey('deck-${listing.id}'),
              listing: listing,
              isTop: false,
              prepareMedia: true,
              railVisible: false,
              preparedVideoController: _preloadedVideos[listing.id],
              onPreparedVideoConsumed: () => _consumePreparedVideo(listing.id),
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
    final verticalDrag = _verticalPagingActive;
    final scale = verticalDrag ? 1.0 : 1.0 - (_horizontalProgress * 0.05);
    final translation = verticalDrag
        ? Offset(0, _verticalOffset)
        : Offset(_dragOffset.dx, 0);
    final cardWidth = MediaQuery.sizeOf(context).width;
    final tiltY = verticalDrag
        ? 0.0
        : (_dragOffset.dx / cardWidth).clamp(-1.0, 1.0) * 0.42;

    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: _onPointerSignal,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..setTranslationRaw(translation.dx, translation.dy, 0)
            ..rotateY(tiltY)
            ..rotateZ(verticalDrag ? 0 : _rotation)
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
                key: ValueKey('deck-${listing.id}'),
                listing: listing,
                isTop: true,
                deckDragging: _isDragging,
                likeOpacity: _likeOpacity,
                nopeOpacity: _nopeOpacity,
                verticalParallaxOffset: verticalDrag ? _verticalOffset : 0,
                preparedVideoController: _preloadedVideos[listing.id],
                onPreparedVideoConsumed: () =>
                    _consumePreparedVideo(listing.id),
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
    );
  }
}
