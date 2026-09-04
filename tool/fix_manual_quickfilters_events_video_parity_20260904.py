from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 anchor, found {count}')
    p.write_text(text.replace(old, new, 1))


# 1) Dashboard listing playback should match Events as closely as possible:
# use the immutable original upload first, then fall back to delivery variants.
# The processed MP4 can be a browser re-recorded artifact; if that artifact has
# duplicated/missing source frames it will visibly stutter even though Events,
# which plays the direct upload, is smooth.
path = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
replace_once(
    path,
    "      final video = (listing.preferredVideoUrl ?? '').trim();\n",
    "      final directVideo = (listing.videoOriginalUrl ?? '').trim();\n"
    "      final video = directVideo.isNotEmpty\n"
    "          ? directVideo\n"
    "          : (listing.preferredVideoUrl ?? '').trim();\n",
    'dashboard original-video-first',
)

# 2) Properties: never rotate automatically. Left/right taps are the only way
# to change listing/media. Manual Play remains available.
path = 'lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart'
replace_once(
    path,
    """  void _scheduleRotation() {
    _rotateTimer?.cancel();
    if (!mounted || widget.media.length <= 1 || _manualPlaying) return;
    _rotateTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _manualPlaying) return;
      unawaited(_advance(1));
    });
  }
""",
    """  void _scheduleRotation() {
    // User-controlled dashboard: never advance photos or videos automatically.
    _rotateTimer?.cancel();
    _rotateTimer = null;
  }
""",
    'disable property auto rotation',
)

# 3) Generic listing quick filters: remove the shared ticker listener that
# automatically advances each card. Edge taps still call _advance().
path = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
p = Path(path)
text = p.read_text()
old = """    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {
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
new = """    // No automatic quick-filter rotation. Media changes only from explicit
    // user left/right taps; videos play only from the Play control.
"""
if new not in text:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'disable generic auto rotation: expected 1 anchor, found {count}')
    text = text.replace(old, new, 1)

# Manual play must not depend on a potentially stale visibility fraction. A tap
# on the visible control is authoritative. Lifecycle/route state still protects
# background playback.
old = "    if (!_canPlay || _userPaused || _visibleFraction < 0.50) return;\n"
new = "    if (!_canPlay || _userPaused) return;\n"
if new not in text:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'manual play visibility gate: expected 1 anchor, found {count}')
    text = text.replace(old, new, 1)

old = """      if ((autoPlay || _manualPlaybackStarted) &&
          !_userPaused &&
          _visibleFraction >= 0.50) {
        _VideoPlaybackCoordinator.activate(this, _visibleFraction);
        await _playIfReady();
      }
"""
new = """      if ((autoPlay || _manualPlaybackStarted) && !_userPaused) {
        _VideoPlaybackCoordinator.activate(this, _visibleFraction);
        await _playIfReady();
      }
"""
if new not in text:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'post-init manual play gate: expected 1 anchor, found {count}')
    text = text.replace(old, new, 1)

# Finishing a video should freeze on that listing, not auto-advance to the next.
old = """      // A dashboard preview is one shot: when it ends, move exactly one item
      // forward and leave that next photo/video PAUSED as the new preview. Do
      // this after the player callback returns so disposing the finished web
      // HtmlElementView/controller cannot race its own listener notification.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_routeActive || _sources.length <= 1) return;
        _advance(1);
      });
"""
new = """      // User-controlled dashboard: finishing a movie never changes listing.
      // Leave the current item selected and paused at the end.
"""
if new not in text:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'video-end auto advance: expected 1 anchor, found {count}')
    text = text.replace(old, new, 1)
p.write_text(text)

# 4) Events: initialize first frame but stay paused until the Play button.
path = 'lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart'
p = Path(path)
text = p.read_text()
old = '  bool _videoPreviewEnabled = true;\n'
new = '  bool _videoPreviewEnabled = false;\n'
if new not in text:
    if text.count(old) != 1:
        raise SystemExit(f'events default paused: expected 1 anchor, found {text.count(old)}')
    text = text.replace(old, new, 1)

# Loading still prepares the current controller so the first frame is visible,
# but it must not auto-advance on completion. Completion listener is harmless
# while paused, yet explicit removal makes the contract unambiguous.
old = """      if (value.position > Duration.zero && remainingMs <= 180) {
        _completionQueued = true;
        unawaited(_advance(1));
      }
"""
new = """      if (value.position > Duration.zero && remainingMs <= 180) {
        _completionQueued = true;
        unawaited(controller.pause());
      }
"""
if new not in text:
    if text.count(old) != 1:
        raise SystemExit(f'events completion freeze: expected 1 anchor, found {text.count(old)}')
    text = text.replace(old, new, 1)

# When another listing player releases Events, do not silently resume it.
old = """    if (_routeActive && _appActive && _videoPreviewEnabled) {
      unawaited(_resumePlayback());
    }
"""
new = """    // Never resume Events automatically; only the user's Play tap may start it.
"""
if new not in text:
    if text.count(old) != 1:
        raise SystemExit(f'events coordinator auto resume: expected 1 anchor, found {text.count(old)}')
    text = text.replace(old, new, 1)
p.write_text(text)

print('manual quick filters + Events video parity patch applied')
