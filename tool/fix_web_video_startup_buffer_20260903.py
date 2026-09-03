from pathlib import Path

path = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = path.read_text()

text = text.replace(
    "    _networkRequestedAt ??= DateTime.now();\n    _networkRequestedAt ??= DateTime.now();",
    "    _networkRequestedAt ??= DateTime.now();",
)
text = text.replace(
    "    _networkRequestedAt = null;\n    _networkRequestedAt = null;",
    "    _networkRequestedAt = null;",
)
text = text.replace(
    "        _initStartedAt = null;\n        _networkRequestedAt = null;",
    "        _initStartedAt = null;",
    1,
)
text = text.replace(
    "        durationMs: durationMs,\n      );\n    }\n\n    if (value.isBuffering",
    "        durationMs: durationMs,\n      );\n      _networkRequestedAt = null;\n    }\n\n    if (value.isBuffering",
    1,
)

old_render = '''          final videoWidget = ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth;
                final cardHeight = constraints.maxHeight;
                if (!cardWidth.isFinite ||
                    !cardHeight.isFinite ||
                    cardWidth <= 0 ||
                    cardHeight <= 0) {
                  return SizedBox.expand(child: VideoPlayer(player));
                }

                final videoAspect = size.width / size.height;
                final cardAspect = cardWidth / cardHeight;
                final renderWidth = videoAspect > cardAspect
                    ? cardHeight * videoAspect
                    : cardWidth;
                final renderHeight = videoAspect > cardAspect
                    ? cardHeight
                    : cardWidth / videoAspect;

                return Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: renderWidth,
                    height: renderHeight,
                    child: VideoPlayer(player),
                  ),
                );
              },
            ),
          );'''

new_render = '''          final videoWidget = ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(player),
                ),
              ),
            ),
          );'''

if old_render not in text:
    raise SystemExit('expected direct-size video block not found')
text = text.replace(old_render, new_render, 1)

marker = '  Future<void> _playIfReady() async {'
helper = '''  int _bufferedAheadMs(VideoPlayerController player) {
    final position = player.value.position;
    for (final range in player.value.buffered) {
      if (position >= range.start && position <= range.end) {
        return (range.end - position).inMilliseconds;
      }
    }
    return 0;
  }

  Future<void> _primeWebPlaybackBuffer(VideoPlayerController player) async {
    if (!kIsWeb || !player.value.isInitialized) return;
    try {
      await player.setVolume(0);
      if (!player.value.isPlaying) await player.play();

      final deadline = DateTime.now().add(const Duration(milliseconds: 900));
      while (DateTime.now().isBefore(deadline)) {
        final value = player.value;
        if (!value.isInitialized || value.hasError) break;
        if (!value.isBuffering && _bufferedAheadMs(player) >= 1200) break;
        await Future<void>.delayed(const Duration(milliseconds: 35));
      }

      await player.pause();
      if (player.value.duration > Duration.zero) {
        await player.seekTo(Duration.zero);
      }
    } catch (_) {
      try {
        await player.pause();
      } catch (_) {}
    }
  }

  Future<void> _playIfReady() async {'''

if marker not in text:
    raise SystemExit('play helper insertion point not found')
text = text.replace(marker, helper, 1)

old_warm = '''      // Decode a real movie frame while the card is still paused. The user sees
      // the actual video preview (not a listing photo) and Play has no cold-start
      // seek/decode penalty. Keep the warm frame silent and stationary.
      if (!autoPlay && next.value.duration.inMilliseconds > 120) {
        await next.seekTo(const Duration(milliseconds: 90));
        await next.pause();
      }
      _attachPlayerListener(next);
      if (autoPlay && _visibleFraction >= 0.50) {
        _VideoPlaybackCoordinator.activate(this, _visibleFraction);
        await _playIfReady();
      }'''

new_warm = '''      // Web/PWA initialization alone can expose only the first frame and then
      // immediately starve when Play is pressed. Prime a short muted buffer while
      // the poster is still on screen, then rewind inside that already-buffered
      // range. Native keeps the lightweight decoded-frame warmup.
      if (!autoPlay && next.value.duration.inMilliseconds > 120) {
        if (kIsWeb) {
          await _primeWebPlaybackBuffer(next);
        } else {
          await next.seekTo(const Duration(milliseconds: 90));
          await next.pause();
        }
      }
      _attachPlayerListener(next);
      if ((autoPlay || _manualPlaybackStarted) &&
          !_userPaused &&
          _visibleFraction >= 0.50) {
        _VideoPlaybackCoordinator.activate(this, _visibleFraction);
        await _playIfReady();
      }'''

if old_warm not in text:
    raise SystemExit('expected 90ms warmup block not found')
text = text.replace(old_warm, new_warm, 1)

if 'final videoWidget = ClipRect(\n            child: LayoutBuilder(' in text:
    raise SystemExit('broken direct-size video layout still present')
if 'await _primeWebPlaybackBuffer(next);' not in text:
    raise SystemExit('web prebuffer call missing')
if "_networkRequestedAt ??= DateTime.now();\n    _networkRequestedAt ??= DateTime.now();" in text:
    raise SystemExit('duplicate network timestamp still present')

path.write_text(text)
print('web video startup patch applied')
