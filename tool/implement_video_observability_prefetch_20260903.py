from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)

# Dashboard quick-filter telemetry + one-next-video prefetch.
q = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = q.read_text()
text = replace_once(
    text,
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/performance/video_playback_telemetry.dart';\n"
    "import 'package:flutter_swipes/src/core/performance/video_predictive_prefetch.dart';\n"
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    'quick filter telemetry imports',
)
text = replace_once(
    text,
    "  bool _webPointerShieldHold = false;\n",
    "  bool _webPointerShieldHold = false;\n"
    "  String? _telemetrySessionId;\n"
    "  String? _telemetryUrl;\n"
    "  DateTime? _initStartedAt;\n"
    "  DateTime? _playRequestedAt;\n"
    "  DateTime? _bufferStartedAt;\n"
    "  bool _firstFrameReported = false;\n"
    "  bool _wasBuffering = false;\n"
    "  bool _telemetryErrorReported = false;\n"
    "  int _rebufferCount = 0;\n",
    'quick filter telemetry fields',
)
helper_anchor = "  void _togglePlayPause() {\n"
helpers = r'''  void _beginTelemetryFor(String url) {
    if (_telemetrySessionId != null && _telemetryUrl == url) return;
    _telemetrySessionId = VideoPlaybackTelemetry.newSessionId();
    _telemetryUrl = url;
    _initStartedAt = DateTime.now();
    _playRequestedAt = null;
    _bufferStartedAt = null;
    _firstFrameReported = false;
    _wasBuffering = false;
    _telemetryErrorReported = false;
    _rebufferCount = 0;
  }

  void _emitPlaybackTelemetry(
    String eventType, {
    int? initMs,
    int? ttffMs,
    int? bufferMs,
    int? positionMs,
    int? durationMs,
    String? errorCode,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    final session = _telemetrySessionId;
    final url = _telemetryUrl;
    if (session == null || url == null) return;
    VideoPlaybackTelemetry.emit(
      sessionId: session,
      eventType: eventType,
      surface: 'quick_filter',
      listingId: _listingIdForUrl(url),
      mediaUrl: url,
      initMs: initMs,
      ttffMs: ttffMs,
      bufferMs: bufferMs,
      rebufferCount: _rebufferCount,
      positionMs: positionMs,
      durationMs: durationMs,
      errorCode: errorCode,
      extra: <String, Object?>{
        'category': widget.handoffCategoryId,
        'visible_fraction': _visibleFraction,
        ...extra,
      },
    );
  }

  void _prefetchNextVideoCandidate() {
    final sources = _sources;
    if (sources.length <= 1 || _visibleFraction < 0.50) return;
    final nextUrl = sources[(_index + 1) % sources.length].trim();
    if (!_isKnownVideoUrl(nextUrl)) return;
    unawaited(
      VideoPredictivePrefetch.prefetchOne(
        url: nextUrl,
        listingId: _listingIdForUrl(nextUrl),
        surface: 'quick_filter',
      ),
    );
  }

'''
text = replace_once(text, helper_anchor, helpers + helper_anchor, 'quick filter telemetry helpers')
text = replace_once(
    text,
    "    _VideoPlaybackCoordinator.activate(this, _visibleFraction);\n\n    setState(() {\n",
    "    _VideoPlaybackCoordinator.activate(this, _visibleFraction);\n"
    "    _playRequestedAt = DateTime.now();\n"
    "    _firstFrameReported = false;\n\n"
    "    setState(() {\n",
    'quick filter play request timestamp',
)
text = replace_once(
    text,
    "    final current = _sources[_index % _sources.length];\n    if (!_videoEnabled || !_isKnownVideoUrl(current)) {\n",
    "    final current = _sources[_index % _sources.length];\n"
    "    if (_visibleFraction >= 0.50) _prefetchNextVideoCandidate();\n"
    "    if (!_videoEnabled || !_isKnownVideoUrl(current)) {\n",
    'quick filter one-next prefetch trigger',
)

old_tick = r'''  void _onPlayerTick() {
    final player = _video;
    if (player == null || !mounted) return;

    final value = player.value;
    final durationMs = value.duration.inMilliseconds;
    final positionMs = value.position.inMilliseconds;
    final ended =
        durationMs > 0 && positionMs >= durationMs - 140 && !value.isPlaying;

    if (ended && _manualPlaybackStarted && !_reportedVideoTurnComplete) {
'''
new_tick = r'''  void _onPlayerTick() {
    final player = _video;
    if (player == null || !mounted) return;

    final value = player.value;
    final now = DateTime.now();
    final durationMs = value.duration.inMilliseconds;
    final positionMs = value.position.inMilliseconds;

    if (value.hasError && !_telemetryErrorReported) {
      _telemetryErrorReported = true;
      _emitPlaybackTelemetry(
        'playback_error',
        positionMs: positionMs,
        durationMs: durationMs,
        errorCode: value.errorDescription ?? 'video_player_error',
      );
    }

    if (!_firstFrameReported &&
        _manualPlaybackStarted &&
        value.isPlaying &&
        positionMs > 0 &&
        _playRequestedAt != null) {
      _firstFrameReported = true;
      _emitPlaybackTelemetry(
        'first_frame',
        ttffMs: now.difference(_playRequestedAt!).inMilliseconds,
        positionMs: positionMs,
        durationMs: durationMs,
      );
    }

    if (value.isBuffering && !_wasBuffering && _firstFrameReported) {
      _bufferStartedAt = now;
    } else if (!value.isBuffering && _wasBuffering && _bufferStartedAt != null) {
      _rebufferCount += 1;
      _emitPlaybackTelemetry(
        'rebuffer',
        bufferMs: now.difference(_bufferStartedAt!).inMilliseconds,
        positionMs: positionMs,
        durationMs: durationMs,
      );
      _bufferStartedAt = null;
    }
    _wasBuffering = value.isBuffering;

    final ended =
        durationMs > 0 && positionMs >= durationMs - 140 && !value.isPlaying;

    if (ended && _manualPlaybackStarted && !_reportedVideoTurnComplete) {
      _emitPlaybackTelemetry(
        'ended',
        positionMs: positionMs,
        durationMs: durationMs,
      );
'''
text = replace_once(text, old_tick, new_tick, 'quick filter player tick telemetry')

text = replace_once(
    text,
    "    _binding = false;\n    _userPaused = true;\n",
    "    _binding = false;\n"
    "    _telemetrySessionId = null;\n"
    "    _telemetryUrl = null;\n"
    "    _initStartedAt = null;\n"
    "    _playRequestedAt = null;\n"
    "    _bufferStartedAt = null;\n"
    "    _firstFrameReported = false;\n"
    "    _wasBuffering = false;\n"
    "    _telemetryErrorReported = false;\n"
    "    _rebufferCount = 0;\n"
    "    _userPaused = true;\n",
    'quick filter telemetry reset',
)
text = replace_once(
    text,
    "    _holdsBudgetSlot = true;\n    _binding = true;\n    _boundVideoUrl = url;\n",
    "    _holdsBudgetSlot = true;\n"
    "    _binding = true;\n"
    "    _boundVideoUrl = url;\n"
    "    _beginTelemetryFor(url);\n"
    "    _initStartedAt = DateTime.now();\n",
    'quick filter init telemetry start',
)
text = replace_once(
    text,
    "      await next.initialize();\n      if (!mounted ||\n",
    "      await next.initialize();\n"
    "      final initStarted = _initStartedAt;\n"
    "      if (initStarted != null) {\n"
    "        _emitPlaybackTelemetry(\n"
    "          'init',\n"
    "          initMs: DateTime.now().difference(initStarted).inMilliseconds,\n"
    "          durationMs: next.value.duration.inMilliseconds,\n"
    "          extra: <String, Object?>{'auto_play': autoPlay},\n"
    "        );\n"
    "        _initStartedAt = null;\n"
    "      }\n"
    "      if (!mounted ||\n",
    'quick filter init telemetry completion',
)
text = replace_once(
    text,
    "    } catch (_) {\n      if (identical(_video, next)) {\n",
    "    } catch (error) {\n"
    "      if (!_telemetryErrorReported) {\n"
    "        _telemetryErrorReported = true;\n"
    "        _emitPlaybackTelemetry(\n"
    "          'playback_error',\n"
    "          errorCode: error.runtimeType.toString(),\n"
    "          extra: <String, Object?>{'phase': 'initialize'},\n"
    "        );\n"
    "      }\n"
    "      if (identical(_video, next)) {\n",
    'quick filter init error telemetry',
)
q.write_text(text)

# Replace the swipe deck's extra decoder preloader with a bounded Range warmup.
c = Path('lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart')
text = c.read_text()
text = replace_once(
    text,
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/performance/video_predictive_prefetch.dart';\n"
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    'swipe deck prefetch import',
)
text = text.replace("  VideoPlayerController? _preloadedPhoto;\n", "")
text = text.replace("  String? _preloadedPhotoUrl;\n", "")
start = text.index("  Future<void> _preloadNextPhoto() async {\n")
end = text.index("\n  Future<void> _adoptPreparedVideo(", start)
new_preload = r'''  Future<void> _preloadNextPhoto() async {
    final media = _media;
    if (media.length <= 1 || !widget.isTop) return;
    final nextUrl = media[(_photoIndex + 1) % media.length];
    if (!_isVideo(nextUrl)) return;
    await VideoPredictivePrefetch.prefetchOne(
      url: nextUrl,
      listingId: widget.listing.id,
      surface: 'swipe_deck',
    );
  }
'''
text = text[:start] + new_preload + text[end:]

adopt_block = r'''    if (url == _preloadedPhotoUrl && _preloadedPhoto != null && _preloadedPhoto!.value.isInitialized) {
      await _adoptPreparedVideo(url, _preloadedPhoto!);
      _preloadedPhoto = null;
      _preloadedPhotoUrl = null;
      unawaited(_preloadNextPhoto());
      return;
    }

    final oldPreload = _preloadedPhoto;
    _preloadedPhoto = null;
    _preloadedPhotoUrl = null;
    if (oldPreload != null) unawaited(oldPreload.dispose());

'''
if adopt_block not in text:
    raise SystemExit('missing anchor: swipe deck old decoder preloader adoption')
text = text.replace(adopt_block, '', 1)
c.write_text(text)

print('video observability and predictive prefetch patch applied')
