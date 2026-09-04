import 'package:flutter/foundation.dart';

class _PlaybackHandlers {
  const _PlaybackHandlers({required this.pause, this.resume});

  final VoidCallback pause;
  final VoidCallback? resume;
}

/// Exclusive media session for dashboard, events, swipe, listing editors, and
/// future Studio vibe templates.
///
/// Surfaces register pause/resume hooks. [claim] guarantees only one audible
/// holder at a time. App lifecycle pauses every registered player and resumes
/// only the holder that was playing.
class AppPlaybackHub {
  AppPlaybackHub._();
  static final AppPlaybackHub instance = AppPlaybackHub._();

  final Map<String, _PlaybackHandlers> _handlers =
      <String, _PlaybackHandlers>{};
  String? _holder;
  String? _pausedHolder;
  bool _backgrounded = false;

  /// Testing seam.
  @visibleForTesting
  String? get holder => _holder;

  @visibleForTesting
  bool get backgrounded => _backgrounded;

  @visibleForTesting
  void resetForTest() {
    _handlers.clear();
    _holder = null;
    _pausedHolder = null;
    _backgrounded = false;
  }

  void register(
    String id, {
    required VoidCallback pause,
    VoidCallback? resume,
  }) {
    _handlers[id] = _PlaybackHandlers(pause: pause, resume: resume);
  }

  void unregister(String id) {
    _handlers.remove(id);
    if (_holder == id) _holder = null;
    if (_pausedHolder == id) _pausedHolder = null;
  }

  /// Take the audible slot. The previous holder is paused immediately.
  void claim(String id) {
    if (_backgrounded) {
      _pausedHolder = id;
      return;
    }
    if (_holder == id) return;
    final previous = _holder;
    _holder = id;
    if (previous != null && previous != id) {
      _handlers[previous]?.pause();
    }
  }

  void release(String id) {
    if (_holder == id) _holder = null;
    if (_pausedHolder == id) _pausedHolder = null;
  }

  /// Phone lock, app switcher, and background. Pauses every registered player.
  void pauseForBackground() {
    if (_backgrounded) return;
    _backgrounded = true;
    _pausedHolder = _holder;
    _holder = null;
    final snapshot = List<_PlaybackHandlers>.from(_handlers.values);
    for (final handler in snapshot) {
      handler.pause();
    }
  }

  /// Resume only the player that was holding the slot when we backgrounded.
  void resumeFromBackground() {
    if (!_backgrounded) return;
    _backgrounded = false;
    final id = _pausedHolder;
    _pausedHolder = null;
    if (id == null) return;
    _holder = id;
    _handlers[id]?.resume?.call();
  }
}
