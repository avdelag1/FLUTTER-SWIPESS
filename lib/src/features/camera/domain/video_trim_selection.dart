/// Immutable trim-window math shared by the editor and tests.
///
/// Swipess video clips resize and move in 5-second steps, with selectable
/// targets every five seconds from 5 through 60 seconds. Videos shorter than five seconds keep
/// their full duration instead of inventing unavailable time.
class VideoTrimSelection {
  const VideoTrimSelection({
    required this.start,
    required this.end,
    required this.duration,
  });

  static const double stepSeconds = 5;
  static const double minSeconds = 5;
  static const double maxSeconds = 60;
  static const double defaultSeconds = 10;

  final double start;
  final double end;
  final double duration;

  double get length => _max(0, end - start);

  factory VideoTrimSelection.initial(double duration) {
    final safeDuration = _max(0, duration);
    final initialLength = _min(defaultSeconds, safeDuration);
    return VideoTrimSelection(
      start: 0,
      end: initialLength,
      duration: safeDuration,
    );
  }

  VideoTrimSelection preset(double requestedSeconds) {
    if (duration <= 0) return this;
    final target = _clamp(requestedSeconds, 0, maxSeconds);
    final window = _min(target, duration);
    final maxStart = _max(0, duration - window);
    var nextStart = _clamp(start, 0, maxStart);
    nextStart = _clamp(_snap(nextStart), 0, maxStart);
    if (nextStart + window > duration) nextStart = duration - window;
    final safeStart = _max(0, nextStart);
    return VideoTrimSelection(
      start: safeStart,
      end: _min(duration, safeStart + window),
      duration: duration,
    );
  }

  /// Move the complete window while preserving its current duration.
  VideoTrimSelection moveTo(double rawStart) {
    final window = length;
    final maxStart = _max(0, duration - window);
    final nextStart = _clamp(_snap(rawStart), 0, maxStart);
    return VideoTrimSelection(
      start: nextStart,
      end: nextStart + window,
      duration: duration,
    );
  }

  /// Resize from the left edge in five-second increments.
  VideoTrimSelection resizeStartTo(double rawStart) {
    if (duration <= minSeconds) return this;
    final minWindow = _min(minSeconds, duration);
    final maxStart = _max(0, end - minWindow);
    var nextStart = _clamp(_snap(rawStart), 0, maxStart);
    if (end - nextStart > maxSeconds) nextStart = end - maxSeconds;
    nextStart = _clamp(nextStart, 0, maxStart);
    return VideoTrimSelection(start: nextStart, end: end, duration: duration);
  }

  /// Resize from the right edge in five-second increments.
  VideoTrimSelection resizeEndTo(double rawEnd) {
    if (duration <= minSeconds) return this;
    final minWindow = _min(minSeconds, duration);
    var nextEnd = _clamp(_snap(rawEnd), start + minWindow, duration);
    if (nextEnd - start > maxSeconds) nextEnd = start + maxSeconds;
    nextEnd = _clamp(nextEnd, start + minWindow, duration);
    return VideoTrimSelection(start: start, end: nextEnd, duration: duration);
  }

  static double _snap(double value) {
    if (!value.isFinite) return 0;
    return (value / stepSeconds).roundToDouble() * stepSeconds;
  }

  static double _clamp(double value, double minimum, double maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}
