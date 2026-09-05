import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_swipes/src/core/services/app_playback_hub.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';

/// Reusable listing/vibe audio for swipe cards, the soundtrack picker, and
/// later Gemini Studio templates.
///
/// One process-wide player. A new [play] stops whatever was running so two
/// soundtracks can never overlap. Trim markers on the URL (`#swipess_trim=`)
/// are honored. Studio templates should call this API rather than creating
/// their own [AudioPlayer].
class AppVibe {
  AppVibe._();
  static final AppVibe instance = AppVibe._();

  static const hubId = 'vibe';

  final ListingSoundtrackPlayer _player = ListingSoundtrackPlayer();
  String? _sessionId;
  bool _pausedByLifecycle = false;
  _VibeRequest? _lastRequest;

  /// Testing seam.
  @visibleForTesting
  String? get sessionId => _sessionId;

  @visibleForTesting
  bool get pausedByLifecycle => _pausedByLifecycle;

  Future<void> play({
    required String sessionId,
    String? presetId,
    String? url,
    XFile? file,
    double volume = .64,
  }) async {
    final request = _VibeRequest(
      sessionId: sessionId,
      presetId: presetId,
      url: url,
      file: file,
      volume: volume,
    );
    _lastRequest = request;
    _pausedByLifecycle = false;
    _sessionId = sessionId;
    AppPlaybackHub.instance.claim(hubId);
    AppPlaybackHub.instance.register(
      hubId,
      pause: () {
        unawaited(pauseForBackground());
      },
      resume: () {
        unawaited(resumeFromBackground());
      },
    );
    await _player.play(
      presetId: presetId,
      url: url,
      file: file,
      volume: volume,
    );
  }

  Future<void> stop({String? sessionId}) async {
    if (sessionId != null && _sessionId != sessionId) return;
    _pausedByLifecycle = false;
    _lastRequest = null;
    _sessionId = null;
    AppPlaybackHub.instance.release(hubId);
    await _player.stop();
  }

  Future<void> pauseForBackground() async {
    if (_sessionId == null) return;
    _pausedByLifecycle = true;
    await _player.pause();
  }

  Future<void> resumeFromBackground() async {
    if (!_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    final request = _lastRequest;
    if (request == null) return;
    await _player.resume();
  }

  Future<void> dispose() async {
    _sessionId = null;
    _lastRequest = null;
    _pausedByLifecycle = false;
    AppPlaybackHub.instance.unregister(hubId);
    await _player.dispose();
  }
}

class _VibeRequest {
  const _VibeRequest({
    required this.sessionId,
    required this.presetId,
    required this.url,
    required this.file,
    required this.volume,
  });

  final String sessionId;
  final String? presetId;
  final String? url;
  final XFile? file;
  final double volume;
}
