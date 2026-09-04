from pathlib import Path

p = Path('lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart')
s = p.read_text()

imp = "import 'package:flutter/foundation.dart';\n"
add_imp = imp + "import 'package:flutter_swipes/src/core/performance/video_playback_telemetry.dart';\n"
if "video_playback_telemetry.dart" not in s:
    if imp not in s:
        raise SystemExit('foundation import target missing')
    s = s.replace(imp, add_imp, 1)

field_target = "  bool _completionQueued = false;\n  late final VoidCallback _dashboardPauseHook;\n"
field_repl = "  bool _completionQueued = false;\n  String? _telemetrySessionId;\n  String? _telemetryUrl;\n  DateTime? _playRequestedAt;\n  DateTime? _lastProgressAt;\n  Duration _lastObservedPosition = Duration.zero;\n  bool _firstFrameReported = false;\n  bool _stallReported = false;\n  bool _telemetryErrorReported = false;\n  late final VoidCallback _dashboardPauseHook;\n"
if field_target in s:
    s = s.replace(field_target, field_repl, 1)
elif "_telemetrySessionId" not in s:
    raise SystemExit('telemetry field target missing')

start_target = """    _rotateTimer?.cancel();
    pauseQuickFilterVideoPlayback();
"""
start_repl = """    _rotateTimer?.cancel();
    final safeIndex = _index % widget.media.length;
    _telemetrySessionId = VideoPlaybackTelemetry.newSessionId();
    _telemetryUrl = url;
    _playRequestedAt = DateTime.now();
    _lastProgressAt = _playRequestedAt;
    _lastObservedPosition = Duration.zero;
    _firstFrameReported = false;
    _stallReported = false;
    _telemetryErrorReported = false;
    VideoPlaybackTelemetry.emit(
      sessionId: _telemetrySessionId!,
      eventType: 'play_request',
      surface: 'property_quick_filter',
      listingId: _listingIdForIndex(safeIndex, url),
      mediaUrl: url,
      extra: const <String, Object?>{'category': 'property'},
    );
    pauseQuickFilterVideoPlayback();
"""
if "eventType: 'play_request'" not in s:
    if start_target not in s:
        raise SystemExit('start playback target missing')
    s = s.replace(start_target, start_repl, 1)

old_tick = """  void _onPlayerTick() {
    final player = _current;
    if (!mounted || player == null || !_manualPlaying) return;
    final value = player.value;
    if (!value.isInitialized || value.duration <= Duration.zero) return;

    // Events loops its active video. Properties must never drop a playing
    // video back into the photo/6-second slideshow at the end of the clip.
    final remaining = value.duration - value.position;
    if (!_completionQueued &&
        remaining <= const Duration(milliseconds: 180)) {
      _completionQueued = true;
      return;
    }
    if (_completionQueued && remaining > const Duration(milliseconds: 350)) {
      _completionQueued = false;
    }
  }
"""
new_tick = """  void _onPlayerTick() {
    final player = _current;
    if (!mounted || player == null || !_manualPlaying) return;
    final value = player.value;
    if (!value.isInitialized || value.duration <= Duration.zero) return;

    final session = _telemetrySessionId;
    final url = _telemetryUrl;
    final now = DateTime.now();
    if (value.hasError && !_telemetryErrorReported && session != null && url != null) {
      _telemetryErrorReported = true;
      VideoPlaybackTelemetry.emit(
        sessionId: session,
        eventType: 'playback_error',
        surface: 'property_quick_filter',
        listingId: _listingIdForIndex(_index % widget.media.length, url),
        mediaUrl: url,
        positionMs: value.position.inMilliseconds,
        durationMs: value.duration.inMilliseconds,
        errorCode: value.errorDescription ?? 'video_player_error',
      );
    }

    if (value.position > _lastObservedPosition + const Duration(milliseconds: 35)) {
      _lastObservedPosition = value.position;
      _lastProgressAt = now;
      _stallReported = false;
      if (!_firstFrameReported && session != null && url != null && _playRequestedAt != null) {
        _firstFrameReported = true;
        VideoPlaybackTelemetry.emit(
          sessionId: session,
          eventType: 'first_frame',
          surface: 'property_quick_filter',
          listingId: _listingIdForIndex(_index % widget.media.length, url),
          mediaUrl: url,
          ttffMs: now.difference(_playRequestedAt!).inMilliseconds,
          positionMs: value.position.inMilliseconds,
          durationMs: value.duration.inMilliseconds,
        );
      }
    } else if (value.isPlaying &&
        !_stallReported &&
        _lastProgressAt != null &&
        now.difference(_lastProgressAt!) >= const Duration(milliseconds: 800) &&
        session != null &&
        url != null) {
      _stallReported = true;
      VideoPlaybackTelemetry.emit(
        sessionId: session,
        eventType: 'playhead_stall',
        surface: 'property_quick_filter',
        listingId: _listingIdForIndex(_index % widget.media.length, url),
        mediaUrl: url,
        positionMs: value.position.inMilliseconds,
        durationMs: value.duration.inMilliseconds,
        bufferMs: now.difference(_lastProgressAt!).inMilliseconds,
      );
    }

    final remaining = value.duration - value.position;
    if (!_completionQueued && remaining <= const Duration(milliseconds: 180)) {
      _completionQueued = true;
      return;
    }
    if (_completionQueued && remaining > const Duration(milliseconds: 350)) {
      _completionQueued = false;
    }
  }
"""
if "eventType: 'playhead_stall'" not in s:
    if old_tick not in s:
        raise SystemExit('player tick target missing')
    s = s.replace(old_tick, new_tick, 1)

old_render = """        if (video && ready && _manualPlaying)
          _CoverVideo(controller: player)
        else if (video)
          poster != null
              ? _still(poster)
              : const ColoredBox(color: Color(0xFF15171C))
        else
          _still(url),
"""
new_render = """        if (video)
          Stack(
            fit: StackFit.expand,
            children: [
              if (poster != null)
                _still(poster)
              else
                const ColoredBox(color: Color(0xFF15171C)),
              // Keep the exact initialized video surface mounted while paused
              // and playing, matching Events. Re-inserting the web platform view
              // on the Play tap can freeze Chrome/PWA on the first decoded frame.
              if (ready)
                _CoverVideo(
                  key: ValueKey('property-video:$url'),
                  controller: player,
                ),
            ],
          )
        else
          _still(url),
"""
if "property-video:$url" not in s:
    if old_render not in s:
        raise SystemExit('render target missing')
    s = s.replace(old_render, new_render, 1)

p.write_text(s)
print('Property stable video surface patch applied')
