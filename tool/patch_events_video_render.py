from pathlib import Path
import re

PATH = Path('lib/src/features/events/presentation/screens/events_screen.dart')
text = PATH.read_text()
original = text

# Replace the playback helper so autoplay always begins muted, never tears down
# an initialized decoder because a browser rejected audible autoplay, and only
# restores volume after playback is actually running.
pattern = re.compile(
    r"  Future<void> _playWithWebFallback\(VideoPlayerController\? p\) async \{.*?\n  \}\n\n  VideoPlayerController\? _player;",
    re.S,
)
replacement = '''  Future<void> _playReliably(VideoPlayerController? player) async {
    if (player == null || !player.value.isInitialized) return;

    final wantsSound =
        ref.read(deckSoundOnProvider) && (!kIsWeb || _sessionAudioUnlocked);
    try {
      // Start muted first. This is accepted by browser autoplay policies and
      // also gives native players a deterministic first frame before audio.
      await player.setVolume(0);
      await player.play();
      if (wantsSound) await player.setVolume(1);
    } catch (_) {
      // A play() rejection is not an initialization failure. Keep the decoder
      // mounted so the first frame remains visible and a user tap can retry.
      try {
        await player.setVolume(0);
      } catch (_) {}
    }
  }

  VideoPlayerController? _player;'''
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('guard failed: playback helper changed')

fields_old = '''  bool _appActive = true;
  IconData? _playbackFeedback;
  Timer? _playbackFeedbackTimer;
'''
fields_new = '''  bool _appActive = true;
  bool _videoLoading = false;
  bool _videoFailed = false;
  bool _sessionAudioUnlocked = !kIsWeb;
  IconData? _playbackFeedback;
  Timer? _playbackFeedbackTimer;
'''
if fields_old not in text:
    raise SystemExit('guard failed: state fields changed')
text = text.replace(fields_old, fields_new, 1)

# Active-page resume must use the reliable playback path.
text = text.replace(
    'unawaited(_playWithWebFallback(player));',
    'unawaited(_playReliably(player));',
)

# Adopted/preloaded controllers are already initialized. Paint them first, then
# start playback after the VideoPlayer widget has had a frame to mount.
adopt_start = text.index('  Future<void> _adoptTransferredVideo(VideoPlayerController player) async {')
adopt_end = text.index('\n  Future<void> _bindVideo() async {', adopt_start)
new_adopt = '''  Future<void> _adoptTransferredVideo(VideoPlayerController player) async {
    try {
      await player.setLooping(true);
      await player.setVolume(0);
      if (mounted && identical(_player, player)) {
        setState(() {
          _videoLoading = false;
          _videoFailed = false;
        });
      }
      if (widget.active && _appActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.active && _appActive && identical(_player, player)) {
            unawaited(_playReliably(player));
          }
        });
      }
    } catch (_) {
      if (!mounted || !identical(_player, player)) return;
      try {
        await player.dispose();
      } catch (_) {}
      _player = null;
      setState(() => _videoFailed = true);
      if (widget.shouldLoadVideo && _hasVideo) unawaited(_bindVideo());
    }
  }
'''
text = text[:adopt_start] + new_adopt + text[adopt_end:]

# Initialize, publish the ready state immediately, then autoplay after paint.
bind_start = text.index('  Future<void> _bindVideo() async {')
bind_end = text.index('\n  @override\n  void didChangeAppLifecycleState', bind_start)
new_bind = '''  Future<void> _bindVideo() async {
    if (_videoLoading) return;
    final media = _media;
    if (media.isEmpty) return;
    final url = media[_mediaIndex % media.length];
    if (!_isVideo(url)) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _videoFailed = true);
      return;
    }

    if (mounted) {
      setState(() {
        _videoLoading = true;
        _videoFailed = false;
      });
    }

    final previous = _player;
    final next = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _player = next;

    try {
      if (previous != null && !identical(previous, next)) {
        try {
          await previous.setVolume(0);
          await previous.pause();
        } catch (_) {}
        try {
          await previous.dispose();
        } catch (_) {}
      }

      await next.initialize();
      await next.setLooping(true);
      await next.setVolume(0);

      final current = _media;
      final stillCurrent =
          mounted &&
          widget.shouldLoadVideo &&
          current.isNotEmpty &&
          current[_mediaIndex % current.length] == url &&
          identical(_player, next);
      if (!stillCurrent) {
        try {
          await next.dispose();
        } catch (_) {}
        if (identical(_player, next)) _player = null;
        return;
      }

      if (!_initialApplied && widget.initialPosition != null) {
        final duration = next.value.duration;
        var target = widget.initialPosition!;
        if (duration > const Duration(milliseconds: 120) && target >= duration) {
          target = duration - const Duration(milliseconds: 120);
        }
        if (target > Duration.zero) await next.seekTo(target);
        _initialApplied = true;
      }

      // Critical: publish `isInitialized` BEFORE awaiting play(). On web/PWA
      // the play future can be delayed by autoplay policy; the moving-picture
      // surface must still mount immediately instead of leaving a black card.
      if (mounted && identical(_player, next)) {
        setState(() {
          _videoLoading = false;
          _videoFailed = false;
        });
      }

      if (widget.active && _appActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.active && _appActive && identical(_player, next)) {
            unawaited(_playReliably(next));
          }
        });
      }
    } catch (_) {
      try {
        await next.dispose();
      } catch (_) {}
      if (identical(_player, next)) _player = null;
      if (mounted) {
        setState(() {
          _videoLoading = false;
          _videoFailed = true;
        });
      }
    } finally {
      if (!mounted) return;
      if (_videoLoading && !identical(_player, next)) {
        setState(() => _videoLoading = false);
      }
    }
  }
'''
text = text[:bind_start] + new_bind + text[bind_end:]

# Resume after background with the same deterministic muted-first path.
resume_start = text.index('  Future<void> _resumeAfterBackground() async {')
resume_end = text.index('\n  @override\n  void dispose()', resume_start)
new_resume = '''  Future<void> _resumeAfterBackground() async {
    final player = _player;
    if (!mounted || !_appActive || !widget.active || player == null) return;
    await _playReliably(player);
  }
'''
text = text[:resume_start] + new_resume + text[resume_end:]

# Retry initialization on tap if there is no usable player; otherwise toggle.
play_start = text.index('  Future<void> _togglePlayback() async {')
play_end = text.index('\n  Future<void> _toggleFavorite()', play_start)
new_play = '''  Future<void> _togglePlayback() async {
    final player = _player;
    if (player == null || !player.value.isInitialized) {
      if (_hasVideo && widget.shouldLoadVideo) unawaited(_bindVideo());
      return;
    }

    final shouldPlay = !player.value.isPlaying;
    try {
      if (shouldPlay) {
        await _playReliably(player);
      } else {
        await player.pause();
      }
      if (!mounted) return;
      _playbackFeedbackTimer?.cancel();
      setState(
        () => _playbackFeedback = shouldPlay
            ? Icons.play_arrow_rounded
            : Icons.pause_rounded,
      );
      _playbackFeedbackTimer = Timer(const Duration(milliseconds: 620), () {
        if (mounted) setState(() => _playbackFeedback = null);
      });
    } catch (_) {}
  }
'''
text = text[:play_start] + new_play + text[play_end:]

# The provider preference is not proof of a fresh browser user activation.
listen_old = '''    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      _player?.setVolume(on ? 1 : 0);
      if (on && widget.active && _appActive) unawaited(_playWithWebFallback(_player));
    });

    final player = _player;
'''
listen_new = '''    ref.listen<bool>(deckSoundOnProvider, (_, on) {
      final player = _player;
      if (player == null || !player.value.isInitialized) return;
      final audible = on && (!kIsWeb || _sessionAudioUnlocked);
      unawaited(player.setVolume(audible ? 1 : 0));
      if (widget.active && _appActive) unawaited(_playReliably(player));
    });

    final effectiveSoundOn =
        soundOn && (!kIsWeb || _sessionAudioUnlocked);
    final player = _player;
'''
if listen_old not in text:
    raise SystemExit('guard failed: sound listener changed')
text = text.replace(listen_old, listen_new, 1)

# Make the loading/error state visible instead of an unexplained black card.
needle = '''                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: activePlayer == null
                            ? SizedBox.expand(
                                key: ValueKey(
                                  'event-video-poster-${event.id}-$index',
                                ),
                              )
                            : RepaintBoundary(
                                key: ValueKey(
                                  'event-video-live-${event.id}-$index',
                                ),
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: activePlayer.value.size.width,
                                    height: activePlayer.value.size.height,
                                    child: VideoPlayer(activePlayer),
                                  ),
                                ),
                              ),
                      ),
'''
replacement = needle + '''                      if (index == _mediaIndex && !ready)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _videoFailed
                                    ? const Icon(
                                        Icons.play_circle_fill_rounded,
                                        key: ValueKey('event-video-retry'),
                                        color: Colors.white,
                                        size: 54,
                                        shadows: [
                                          Shadow(color: Colors.black54, blurRadius: 14),
                                        ],
                                      )
                                    : const SizedBox(
                                        key: ValueKey('event-video-loading'),
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
'''
if needle not in text:
    raise SystemExit('guard failed: video AnimatedSwitcher changed')
text = text.replace(needle, replacement, 1)

sound_old = '''                _RailAction(
                  icon: soundOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  onTap: () {
                    widget.onChromeInteraction();
                    unlockDeckMedia();
                    ref.read(deckSoundOnProvider.notifier).setSoundOn(!soundOn);
                    final player = _player;
                    if (player != null && player.value.isInitialized) {
                      player.setVolume(soundOn ? 0 : 1);
                      if (!soundOn && widget.active) {
                        unawaited(_playWithWebFallback(player));
                      }
                    }
                  },
                ),
'''
sound_new = '''                _RailAction(
                  icon: effectiveSoundOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  onTap: () {
                    widget.onChromeInteraction();
                    unlockDeckMedia();
                    _sessionAudioUnlocked = true;
                    final nextSoundOn = !effectiveSoundOn;
                    ref
                        .read(deckSoundOnProvider.notifier)
                        .setSoundOn(nextSoundOn);
                    if (mounted) setState(() {});
                    final player = _player;
                    if (player != null && player.value.isInitialized) {
                      unawaited(player.setVolume(nextSoundOn ? 1 : 0));
                      if (nextSoundOn && widget.active && _appActive) {
                        unawaited(_playReliably(player));
                      }
                    }
                  },
                ),
'''
if sound_old not in text:
    raise SystemExit('guard failed: sound button changed')
text = text.replace(sound_old, sound_new, 1)

# Any lingering legacy helper call means a concurrent edit changed the patch surface.
if '_playWithWebFallback' in text:
    raise SystemExit('guard failed: legacy helper reference remains')

if text == original:
    raise SystemExit('no changes applied')
PATH.write_text(text)
