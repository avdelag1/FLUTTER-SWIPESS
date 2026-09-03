import 'package:video_player/video_player.dart';

class SwipeDeckMediaHandoffData {
  const SwipeDeckMediaHandoffData({
    required this.videoUrl,
    required this.position,
    this.controller,
    this.wantSound = false,
    this.listingId,
    this.categoryId,
  });

  final String videoUrl;
  final Duration position;

  /// Already-initialized dashboard quick-filter player. When present, the swipe
  /// deck adopts this exact controller instead of opening the same network
  /// video again so audio can continue seamlessly after the tap.
  final VideoPlayerController? controller;
  final bool wantSound;

  /// Listing identity carried with the dashboard video so the destination deck
  /// can put the exact previewed listing first before its first frame paints.
  final String? listingId;
  final String? categoryId;
}

/// One-shot in-memory handoff from a dashboard quick filter to the swipe deck.
class SwipeDeckMediaHandoff {
  SwipeDeckMediaHandoff._();

  static SwipeDeckMediaHandoffData? _pending;

  static String? get pendingListingId => _pending?.listingId;
  static String? get pendingCategoryId => _pending?.categoryId;

  static void set(SwipeDeckMediaHandoffData data) => _pending = data;

  static SwipeDeckMediaHandoffData? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  static void clear() => _pending = null;
}
