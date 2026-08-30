from pathlib import Path

TARGET = Path('lib/src/features/events/presentation/screens/events_screen.dart')
WORKFLOW = Path('.github/workflows/fix-events-video-feed.yml')
SELF = Path('.github/scripts/fix_events_video_feed.py')

text = TARGET.read_text()
original = text

old_is_video = """  bool _isVideo(String value) {
    final l = value.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('/videos/');
  }
"""
new_is_video = """  bool _isVideo(String value) {
    // `video_url` is authoritative. CDN/Supabase URLs do not have to expose a
    // file extension, so never downgrade a declared event video into an image
    // just because its public URL is opaque.
    final declared = event.videoUrl?.trim();
    if (declared != null && declared.isNotEmpty && value.trim() == declared) {
      return true;
    }

    final uri = Uri.tryParse(value);
    final path = (uri?.path ?? value).toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.webm') ||
        path.endsWith('.mov') ||
        path.contains('/videos/');
  }
"""
if old_is_video not in text:
    raise SystemExit('events patch guard failed: _isVideo block changed')
text = text.replace(old_is_video, new_is_video, 1)

bind_start = text.index('  Future<void> _bindVideo() async {')
bind_end = text.index('\n  @override\n  void didChangeAppLifecycleState', bind_start)
new_bind = """  Future<void> _bindVideo() async {
    final m = _media;
    if (m.isEmpty) return;
    final url = m[_mediaIndex % m.length];
    if (!_isVideo(url)) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;

    final previous = _player;
    final next = VideoPlayerController.networkUrl(uri);
    _player = next;
    if (previous != null && !identical(previous, next)) {
      try {
        await previous.pause();
      } catch (_) {}
      try {
        await previous.dispose();
      } catch (_) {}
    }

    try {
      await next.initialize();
      await next.setLooping(true);

      // The user may have horizontally changed media while this network video
      // was warming. Never let a stale decoder start playing behind an image.
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

      await next.setVolume(ref.read(deckSoundOnProvider) ? 1 : 0);
      if (widget.active && _appActive) await next.play();
      if (mounted && identical(_player, next)) setState(() {});
    } catch (_) {
      try {
        await next.dispose();
      } catch (_) {}
      if (identical(_player, next)) {
        _player = null;
        if (mounted) setState(() {});
      }
    }
  }
"""
text = text[:bind_start] + new_bind + text[bind_end:]

play_start = text.index('  Future<void> _togglePlayback() async {')
play_end = text.index('\n  Future<void> _toggleFavorite()', play_start)
old_play = text[play_start:play_end]
new_play = """  Future<void> _togglePlayback() async {
    final player = _player;
    // If a previous network attempt failed, a tap on the poster is also a
    // natural retry gesture. Do not spawn a duplicate decoder while one is
    // already initializing.
    if (player == null) {
      if (_hasVideo && widget.shouldLoadVideo) unawaited(_bindVideo());
      return;
    }
    if (!player.value.isInitialized) return;

    final shouldPlay = !player.value.isPlaying;
    try {
      if (shouldPlay) {
        await player.play();
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
"""
if 'if (player == null || !player.value.isInitialized) return;' not in old_play:
    raise SystemExit('events patch guard failed: playback block changed')
text = text[:play_start] + new_play + text[play_end:]

build_marker = """  @override
  Widget build(BuildContext context) {
    final favorited =
"""
poster_helper = """  Widget _videoPoster(BuildContext context) {
    String? poster;
    final primary = event.imageUrl?.trim();
    if (primary != null && primary.isNotEmpty && !_isVideo(primary)) {
      poster = primary;
    }
    if (poster == null) {
      for (final candidate in event.gallery) {
        final value = candidate.trim();
        if (value.isNotEmpty && !_isVideo(value)) {
          poster = value;
          break;
        }
      }
    }

    if (poster == null) {
      return const ColoredBox(color: Color(0xFF16161C));
    }
    return Image.network(
      poster,
      fit: BoxFit.cover,
      cacheWidth: (MediaQuery.sizeOf(context).width * 2)
          .round()
          .clamp(640, 1800),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const ColoredBox(color: Color(0xFF16161C)),
      errorBuilder: (_, _, _) =>
          const ColoredBox(color: Color(0xFF16161C)),
    );
  }

"""
if build_marker not in text:
    raise SystemExit('events patch guard failed: build marker changed')
text = text.replace(build_marker, poster_helper + build_marker, 1)

old_item = """              itemBuilder: (context, index) {
                final url = _media[index];
                final isVid = _isVideo(url);
                if (isVid && ready) {
                  return RepaintBoundary(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: player.value.size.width,
                        height: player.value.size.height,
                        child: VideoPlayer(player),
                      ),
                    ),
                  );
                } else if (!isVid) {
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    cacheWidth: (MediaQuery.sizeOf(context).width * 2)
                        .round()
                        .clamp(640, 1800),
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF16161C)),
                  );
                }
                return const ColoredBox(color: Color(0xFF16161C));
              },
"""
new_item = """              itemBuilder: (context, index) {
                final url = _media[index];
                final isVid = _isVideo(url);
                if (isVid) {
                  final activePlayer = index == _mediaIndex && ready
                      ? player
                      : null;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Keep the event artwork painted while the decoder warms
                      // so opening/swiping never flashes a dead black frame.
                      _videoPoster(context),
                      AnimatedSwitcher(
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
                    ],
                  );
                }

                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: (MediaQuery.sizeOf(context).width * 2)
                      .round()
                      .clamp(640, 1800),
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF16161C)),
                );
              },
"""
if old_item not in text:
    raise SystemExit('events patch guard failed: media itemBuilder changed')
text = text.replace(old_item, new_item, 1)

# Invalidate a warming video as soon as the horizontal media pager moves onto
# an image. This prevents a stale initialize() from later starting off-screen.
old_image_dispose = """                } else if (_player != null) {
                  _player?.dispose();
                  _player = null;
                }
"""
new_image_dispose = """                } else if (_player != null) {
                  unawaited(_player?.pause());
                  unawaited(_player?.dispose());
                  _player = null;
                }
"""
if old_image_dispose not in text:
    raise SystemExit('events patch guard failed: media disposal block changed')
text = text.replace(old_image_dispose, new_image_dispose, 1)

if text == original:
    raise SystemExit('events patch produced no changes')
TARGET.write_text(text)

# This is a one-shot guarded patch. The workflow commits these deletions with
# the real Dart change so main does not accumulate maintenance scaffolding.
SELF.unlink(missing_ok=True)
WORKFLOW.unlink(missing_ok=True)
