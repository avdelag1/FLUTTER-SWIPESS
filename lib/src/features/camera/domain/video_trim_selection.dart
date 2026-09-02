import 'dart:math' as math;

/// Immutable trim-window math shared by the editor and tests.
///
/// Swipess video clips resize and move in 5-second steps, with selectable
/// targets of 5, 10, 15, or 20 seconds. Videos shorter than five seconds keep
/// their full duration instead of inventing unavailable time.
class VideoTrimSelection {
  const VideoTrimSelection({
    required this.start,
    required this.end,
    required this.duration,
  });

  static const double stepSeconds = 5;
  static const double minSeconds = 5;
  static const double maxSeconds = 20;
  static const double defaultSeconds = 10;

  final double start;
  final double end;
  final double duration;

  double get length => math.max(0, end - start);

  factory VideoTrimSelection.initial(double duration) {
    final safeDuration = math.max(0, duration);
    final initialLength = math.min(defaultSeconds, safeDuration);
    return VideoTrimSelection(
      start: 0,
      end: initialLength,
      duration: safeDuration,
    );
  }

  VideoTrimSelection preset(double requestedSeconds) {
    if (duration <= 0) return this;
    final target = requestedSeconds.clamp(0.0, maxSeconds);
    final length = math.min(target, duration);
    var nextStart = start.clamp(0.0, math.max(0, duration - length));
    nextStart = _snap(nextStart).clamp(0.0, math.max(0, duration - length));
    if (nextStart + length > duration) nextStart = duration - length;
    return VideoTrimSelection(
      start: math.max(0, nextStart),
      end: math.min(duration, math.max(0, nextStart) + length),
      duration: duration,
    );
  }

  /// Move the complete window while preserving its current duration.
  VideoTrimSelection moveTo(double rawStart) {
    final window = length;
    final maxStart = math.max(0, duration - window);
    final nextStart = _snap(rawStart).clamp(0.0, maxStart);
    return VideoTrimSelection(
      start: nextStart,
      end: nextStart + window,
      duration: duration,
    );
  }

  /// Resize from the left edge in five-second increments.
  VideoTrimSelection resizeStartTo(double rawStart) {
    if (duration <= minSeconds) return this;
    final minWindow = math.min(minSeconds, duration);
    var nextStart = _snap(rawStart);
    nextStart = nextStart.clamp(0.0, math.max(0, end - minWindow));
    if (end - nextStart > maxSeconds) nextStart = end - maxSeconds;
    nextStart = nextStart.clamp(0.0, math.max(0, end - minWindow));
    return VideoTrimSelection(
      start: nextStart,
      end: end,
      duration: duration,
    );
  }

  /// Resize from the right edge in five-second increments.
  VideoTrimSelection resizeEndTo(double rawEnd) {
    if (duration <= minSeconds) return this;
    final minWindow = math.min(minSeconds, duration);
    var nextEnd = _snap(rawEnd);
    nextEnd = nextEnd.clamp(start + minWindow, duration);
    if (nextEnd - start > maxSeconds) nextEnd = start + maxSeconds;
    nextEnd = nextEnd.clamp(start + minWindow, duration);
    return VideoTrimSelection(
      start: start,
      end: nextEnd,
      duration: duration,
    );
  }

  static double _snap(double value) {
    if (!value.isFinite) return 0;
    return (value / stepSeconds).roundToDouble() * stepSeconds;
  }
}
