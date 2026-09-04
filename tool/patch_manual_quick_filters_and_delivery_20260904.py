from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(path, old, new, label):
    text = read(path)
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 anchor, found {count} in {path}')
    write(path, text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# 1) NO automatic dashboard quick-filter rotation anywhere.
# ---------------------------------------------------------------------------
path = 'lib/src/features/dashboard/presentation/providers/quick_filter_rotate_provider.dart'
text = read(path)
text = text.replace(
    '    _armStillWindow();\n    return 0;\n',
    '    // Dashboard media is user-driven only. Never start an automatic timer.\n    return 0;\n',
    1,
)
text = re.sub(
    r"  void _armStillWindow\(\) \{.*?\n  \}\n\n  void _advance\(\) \{.*?\n  \}",
    """  void _armStillWindow() {
    // Intentionally no-op: photos/videos change only from explicit user input.
    _timer?.cancel();
    _timer = null;
  }

  void _advance() {
    // Intentionally no-op: keep the current quick-filter item stable.
  }""",
    text,
    count=1,
    flags=re.S,
)
text = text.replace(
    '    state = state + 1;\n    _armStillWindow();\n',
    '    // Do not advance automatically when a manually played video ends.\n',
    1,
)
write(path, text)

# ---------------------------------------------------------------------------
# 2) Generic listing quick filters: stable item order, no auto advance, and
#    a user Play tap MUST start even if visibility measurement is stale.
# ---------------------------------------------------------------------------
path = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
text = read(path)

shuffle_block = """    if (order.length > 2) {
      final hero = order.removeAt(0);
      order.shuffle(
        math.Random(
          DateTime.now().microsecondsSinceEpoch ^ widget.rotateSlot * 7919,
        ),
      );
      order.insert(0, hero);
    }
"""
if shuffle_block in text:
    text = text.replace(
        shuffle_block,
        '    // Preserve server/listing order. Media never changes unless the user asks.\n',
        1,
    )

text = text.replace(
    '    if (!_canPlay || _userPaused || _visibleFraction < 0.50) return;\n',
    '    if (!_canPlay || _userPaused) return;\n',
    1,
)
text = text.replace(
    '      if (autoPlay && _visibleFraction >= 0.50) await _playIfReady();\n',
    '      if (autoPlay) await _playIfReady();\n',
    1,
)
text = text.replace(
    """      if ((autoPlay || _manualPlaybackStarted) &&
          !_userPaused &&
          _visibleFraction >= 0.50) {
""",
    """      if ((autoPlay || _manualPlaybackStarted) && !_userPaused) {
""",
    1,
)
text = text.replace(
    """    if (_visibleFraction >= 0.50) {
      if (_VideoPlaybackCoordinator.activate(this, _visibleFraction)) {
        unawaited(_playIfReady());
      }
    } else {
      _pauseForCoordinator();
    }
""",
    """    // A user can only press Play on a card they can see. Do not let a stale
    // geometry sample (<50%) turn a successful tap into a frozen first frame.
    if (_visibleFraction > 0.02) {
      if (_VideoPlaybackCoordinator.activate(this, _visibleFraction)) {
        unawaited(_playIfReady());
      }
    } else {
      _pauseForCoordinator();
    }
""",
    1,
)
text = text.replace(
    '    if (_canPlay && _visibleFraction >= 0.50) {\n',
    '    if (_canPlay && _visibleFraction > 0.02) {\n',
    1,
)

end_advance = """
      // A dashboard preview is one shot: when it ends, move exactly one item
      // forward and leave that next photo/video PAUSED as the new preview. Do
      // this after the player callback returns so disposing the finished web
      // HtmlElementView/controller cannot race its own listener notification.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_routeActive || _sources.length <= 1) return;
        _advance(1);
      });
"""
if end_advance in text:
    text = text.replace(
        end_advance,
        '\n      // Stay on this exact item. The user decides when to go left/right.\n',
        1,
    )

listen_block = """    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {
      if (!_routeActive) return;
      final slots = _rotateSlotCount;
      final normalizedSlot = widget.rotateSlot % slots;
      final target = normalizedSlot < 0
          ? normalizedSlot + slots
          : normalizedSlot;
      if (next % slots != target) return;

      // On each round only this card changes listing. Video sources stay on
      // their static poster until the user explicitly presses Play.
      if (prev != null) _advance(1);
    });

"""
if listen_block in text:
    text = text.replace(
        listen_block,
        '    // No shared rotation listener: this card moves only on user taps.\n\n',
        1,
    )
write(path, text)

# ---------------------------------------------------------------------------
# 3) Properties dedicated player: same simple controller path as Events, but
#    no timers and no looping. User starts/stops and navigates manually.
# ---------------------------------------------------------------------------
path = 'lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart'
text = read(path)
text = text.replace(
    '      await controller.setLooping(true);\n',
    '      await controller.setLooping(false);\n',
    1,
)
text, count = re.subn(
    r"  void _scheduleRotation\(\) \{.*?\n  \}\n\n  Future<void> _playWithWebFallback",
    """  void _scheduleRotation() {
    // Intentionally no-op. Property cards never rotate unless the user taps
    // the left/right side of the card.
    _rotateTimer?.cancel();
    _rotateTimer = null;
  }

  Future<void> _playWithWebFallback""",
    text,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit(f'property manual rotation patch matched {count}')
write(path, text)

# ---------------------------------------------------------------------------
# 4) Events quick filter: preload a frame but start PAUSED. A completed video
#    stays on the same event; left/right changes are manual and stay paused.
# ---------------------------------------------------------------------------
path = 'lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart'
text = read(path)
text = text.replace(
    '  bool _videoPreviewEnabled = true;\n',
    '  bool _videoPreviewEnabled = false;\n',
    1,
)
text = text.replace(
    """      if (value.position > Duration.zero && remainingMs <= 180) {
        _completionQueued = true;
        unawaited(_advance(1));
      }
""",
    """      if (value.position > Duration.zero && remainingMs <= 180) {
        _completionQueued = true;
        unawaited(() async {
          try {
            await controller.pause();
          } catch (_) {}
          if (!mounted || !identical(controller, _current)) return;
          setState(() => _videoPreviewEnabled = false);
        }());
      }
""",
    1,
)
text = text.replace(
    """    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 180)) {
      _completionQueued = true;
      await _advance(1);
      return;
    }

    await _applySound();
""",
    """    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 180)) {
      await current.seekTo(Duration.zero);
      _completionQueued = false;
    }

    await _applySound();
""",
    1,
)
text = text.replace(
    """    _switching = true;
    try {
""",
    """    _switching = true;
    // Navigation is user-driven and the newly selected event stays paused.
    if (_videoPreviewEnabled && mounted) {
      setState(() => _videoPreviewEnabled = false);
    }
    try {
""",
    1,
)
write(path, text)

# ---------------------------------------------------------------------------
# 5) Listing model: explicitly read/use the processed playback/poster columns
#    that already exist in Supabase instead of relying on video_url promotion.
# ---------------------------------------------------------------------------
path = 'lib/src/features/swipes/domain/models/listing.dart'
text = read(path)
if 'final String? videoPlaybackUrl;' not in text:
    text = text.replace(
        '  final String? videoOriginalUrl;\n  final String? videoHlsUrl;\n',
        '  final String? videoOriginalUrl;\n  final String? videoPlaybackUrl;\n  final String? videoPosterUrl;\n  final String? videoHlsUrl;\n',
        1,
    )
    text = text.replace(
        '    this.videoOriginalUrl,\n    this.videoHlsUrl,\n',
        '    this.videoOriginalUrl,\n    this.videoPlaybackUrl,\n    this.videoPosterUrl,\n    this.videoHlsUrl,\n',
        1,
    )
    text = text.replace(
        "      videoOriginalUrl: json['video_original_url'] as String?,\n      videoHlsUrl: json['video_hls_url'] as String?,\n",
        "      videoOriginalUrl: json['video_original_url'] as String?,\n      videoPlaybackUrl: json['video_playback_url'] as String?,\n      videoPosterUrl: json['video_poster_url'] as String?,\n      videoHlsUrl: json['video_hls_url'] as String?,\n",
        1,
    )

old_getter = """  String? get preferredVideoUrl {
    final original = videoOriginalUrl?.trim();
    final mp4 = videoUrl?.trim();
    final hls = videoHlsUrl?.trim();

    // The video pipeline promotes `video_url` to the delivery MP4 when it is
    // ready and keeps `video_original_url` as the immutable raw upload. Web/PWA
    // must prefer the promoted fast-start MP4; preferring the raw file made a
    // clip look fine to its uploader but cold/stuttery on another device.
    if (kIsWeb) {
      if (mp4 != null && mp4.isNotEmpty) return mp4;
      if (original != null && original.isNotEmpty) return original;
      return hls == null || hls.isEmpty ? null : hls;
    }

    // Native apps keep adaptive delivery first, then the processed MP4, with
    // the original source as a final compatibility fallback.
    if (hls != null && hls.isNotEmpty) return hls;
    if (mp4 != null && mp4.isNotEmpty) return mp4;
    return original == null || original.isEmpty ? null : original;
  }
"""
new_getter = """  String? get preferredVideoUrl {
    final playback = videoPlaybackUrl?.trim();
    final original = videoOriginalUrl?.trim();
    final mp4 = videoUrl?.trim();
    final hls = videoHlsUrl?.trim();

    // `video_playback_url` is the explicit processed delivery asset. Prefer it
    // on web/PWA instead of assuming `video_url` has already been promoted.
    if (kIsWeb) {
      if (playback != null && playback.isNotEmpty) return playback;
      if (mp4 != null && mp4.isNotEmpty) return mp4;
      if (original != null && original.isNotEmpty) return original;
      return hls == null || hls.isEmpty ? null : hls;
    }

    // Native prefers adaptive HLS, then the processed progressive asset.
    if (hls != null && hls.isNotEmpty) return hls;
    if (playback != null && playback.isNotEmpty) return playback;
    if (mp4 != null && mp4.isNotEmpty) return mp4;
    return original == null || original.isEmpty ? null : original;
  }
"""
if old_getter in text:
    text = text.replace(old_getter, new_getter, 1)
elif new_getter not in text:
    raise SystemExit('preferredVideoUrl getter anchor missing')
write(path, text)

print('manual quick-filter + explicit processed video delivery patch applied')
