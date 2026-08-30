import 'package:video_player/video_player.dart';

class SwipeDeckMediaHandoffData {
  const SwipeDeckMediaHandoffData({
    required this.videoUrl,
    required this.position,
    this.controller,
    this.wantSound = false,
  });

  final String videoUrl;
  final Duration position;

  /// Already-initialized dashboard quick-filter player. When present, the swipe
  /// deck adopts this exact controller instead of opening the same network
  /// video again so audio can continue seamlessly after the tap.
  final VideoPlayerController? controller;
  final bool wantSound;
}

/// One-shot in-memory handoff from a dashboard quick filter to the swipe deck.
class SwipeDeckMediaHandoff {
  SwipeDeckMediaHandoff._();

  static SwipeDeckMediaHandoffData? _pending;

  static void set(SwipeDeckMediaHandoffData data) => _pending = data;

  static SwipeDeckMediaHandoffData? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  static void clear() => _pending = null;
}
