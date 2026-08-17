class EventPreviewHandoffData {
  const EventPreviewHandoffData({
    required this.eventId,
    required this.position,
  });

  final String eventId;
  final Duration position;
}

/// One-shot in-memory handoff from the dashboard Events quick filter to the
/// full-screen Events feed. It lets the feed open the same event at the same
/// playback position without keeping two video/audio players alive.
class EventPreviewHandoff {
  EventPreviewHandoff._();

  static EventPreviewHandoffData? _pending;

  static void set({required String eventId, required Duration position}) {
    _pending = EventPreviewHandoffData(eventId: eventId, position: position);
  }

  static EventPreviewHandoffData? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  static void clear() => _pending = null;
}
