import 'package:video_player/video_player.dart';

class EventPreviewHandoffData {
  const EventPreviewHandoffData({
    required this.eventId,
    required this.position,
    this.controller,
  });

  final String eventId;
  final Duration position;

  /// Already-initialized dashboard player. When present, the Events feed adopts
  /// this exact controller instead of opening the same network video again.
  final VideoPlayerController? controller;
}

/// One-shot in-memory handoff from the dashboard Events quick filter to the
/// full-screen Events feed.
///
/// The active player can be transferred together with the event id and current
/// position, making the preview-to-fullscreen transition effectively immediate
/// while still keeping a position-only fallback for any uninitialized video.
class EventPreviewHandoff {
  EventPreviewHandoff._();

  static EventPreviewHandoffData? _pending;

  static void set({
    required String eventId,
    required Duration position,
    VideoPlayerController? controller,
  }) {
    _pending = EventPreviewHandoffData(
      eventId: eventId,
      position: position,
      controller: controller,
    );
  }

  static EventPreviewHandoffData? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  static void clear() => _pending = null;
}
