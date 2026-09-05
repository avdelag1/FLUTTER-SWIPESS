from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f'{label}: already applied')
        return text
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    print(f'{label}: patched')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# QUICK FILTER PLAYBACK
# ---------------------------------------------------------------------------
p = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
s = p.read_text()

s = replace_once(
    s,
    """  static void release(\n    _QuickFilterMediaState state, {\n    bool resumeEventsWhenIdle = true,\n  }) {""",
    """  static void release(\n    _QuickFilterMediaState state, {\n    bool resumeEventsWhenIdle = false,\n  }) {""",
    'do not auto-resume Events when listing releases playback',
)

s = replace_once(
    s,
    """      _VideoPlaybackCoordinator.release(this);\n      return;""",
    """      // Pausing a listing must NOT restart Events. Events only reclaims\n      // dashboard playback from its own explicit Play tap.\n      _VideoPlaybackCoordinator.release(\n        this,\n        resumeEventsWhenIdle: false,\n      );\n      return;""",
    'manual listing pause keeps Events paused',
)

old_visibility = """    if (_visibleFraction >= 0.20) {\n      if (_VideoPlaybackCoordinator.activate(this, _visibleFraction)) {\n        unawaited(_playIfReady());\n      }\n    } else {\n      _pauseForCoordinator();\n    }"""
new_visibility = """    // A deliberate Play tap is authoritative. Once the user starts a\n    // non-Events quick-filter video, visibility sampling must never stop it a\n    // few seconds later. It keeps ownership until the user starts another\n    // quick-filter video, explicitly pauses it, opens another media surface,\n    // or presses Play on Events.\n    if (!_VideoPlaybackCoordinator.owns(this)) {\n      _VideoPlaybackCoordinator.activate(this, _visibleFraction);\n    }\n    unawaited(_playIfReady());"""
s = replace_once(
    s,
    old_visibility,
    new_visibility,
    'manual listing playback ignores transient visibility fraction',
)

s = replace_once(
    s,
    """  Future<void> _playIfReady() async {\n    if (!_canPlay || _userPaused || _visibleFraction < 0.50) return;""",
    """  Future<void> _playIfReady() async {\n    // This method is reached only after an explicit Play intent. Do not gate\n    // that user gesture on an asynchronously sampled visibility percentage.\n    if (!_canPlay || _userPaused) return;""",
    'first Play tap no longer waits for 50 percent visibility',
)

s = replace_once(
    s,
    """    if (url == _boundVideoUrl && _video != null) {\n      if (autoPlay && _visibleFraction >= 0.20) await _playIfReady();\n      return;\n    }""",
    """    if (url == _boundVideoUrl && _video != null) {\n      if (autoPlay) await _playIfReady();\n      return;\n    }""",
    'warm controller plays immediately on first tap',
)

s = replace_once(
    s,
    """      // Dashboard listing previews play once. Their real end advances the\n      // shared card sequence; looping would prevent the next card from moving.\n      await next.setLooping(false);""",
    """      // Non-Events dashboard videos are manual-only. After the user presses\n      // Play, keep that chosen video moving continuously until another explicit\n      // playback action takes ownership.\n      await next.setLooping(true);""",
    'manual quick-filter video loops until explicitly stopped',
)

s = replace_once(
    s,
    """      if (autoPlay && _visibleFraction >= 0.20) {\n        _VideoPlaybackCoordinator.activate(this, _visibleFraction);\n        await _playIfReady();\n      }""",
    """      if (autoPlay) {\n        if (!_VideoPlaybackCoordinator.owns(this)) {\n          _VideoPlaybackCoordinator.activate(this, _visibleFraction);\n        }\n        await _playIfReady();\n      }""",
    'initialized video honors first Play tap regardless visibility timing',
)

old_tick = """  void _onPlayerTick() {\n    final player = _video;\n    if (player == null || !mounted) return;\n\n    final value = player.value;\n    final durationMs = value.duration.inMilliseconds;\n    final positionMs = value.position.inMilliseconds;\n    final ended =\n        durationMs > 0 && positionMs >= durationMs - 140 && !value.isPlaying;\n\n    if (ended && _manualPlaybackStarted && !_reportedVideoTurnComplete) {\n      _reportedVideoTurnComplete = true;\n      _manualPlaybackStarted = false;\n      _userPaused = true;\n      ref\n          .read(quickFilterRotateTickProvider.notifier)\n          .resumeAfterManualVideo(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n      _VideoPlaybackCoordinator.release(this);\n    }\n\n    final playing = value.isPlaying;"""
new_tick = """  void _onPlayerTick() {\n    final player = _video;\n    if (player == null || !mounted) return;\n\n    final value = player.value;\n    // The controller itself loops. Never hand playback back to Events merely\n    // because a short listing clip reached its end.\n    final playing = value.isPlaying;"""
s = replace_once(
    s,
    old_tick,
    new_tick,
    'video end no longer releases Events ownership',
)

s = replace_once(
    s,
    """    if (_canPlay && _visibleFraction >= 0.20) {\n      player.setVolume(soundOn && (_mediaUnlocked || !kIsWeb) ? 1 : 0);""",
    """    if (_canPlay && _VideoPlaybackCoordinator.owns(this)) {\n      player.setVolume(soundOn && (_mediaUnlocked || !kIsWeb) ? 1 : 0);""",
    'sound toggle follows explicit playback owner not visibility',
)

s = replace_once(
    s,
    """    final videoPlaying =\n        _videoPreviewEnabled &&\n        player != null &&\n        player.value.isInitialized &&\n        player.value.isPlaying;""",
    """    // Show Pause immediately after the first accepted Play tap, even while\n    // the network controller is still initializing. This gives instant visual\n    // feedback instead of making users tap three or four times.\n    final videoPlaying =\n        _videoPreviewEnabled && _manualPlaybackStarted && !_userPaused;""",
    'play button reflects accepted play intent immediately',
)

p.write_text(s)


# ---------------------------------------------------------------------------
# EVENTS: ONLY EVENTS AUTOPLAYS; ITS PLAY BUTTON EXPLICITLY RECLAIMS OWNERSHIP
# ---------------------------------------------------------------------------
p = Path('lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart')
s = p.read_text()

s = replace_once(
    s,
    """  void _pauseForListingPreview() {\n    if (_externallyPaused) return;\n    _externallyPaused = true;\n    final current = _current;""",
    """  void _pauseForListingPreview() {\n    if (_externallyPaused) return;\n    if (mounted) {\n      setState(() => _externallyPaused = true);\n    } else {\n      _externallyPaused = true;\n    }\n    final current = _current;""",
    'Events play icon updates immediately when listing takes ownership',
)

s = replace_once(
    s,
    """  void _resumeAfterListingPreview() {\n    if (!_externallyPaused) return;\n    _externallyPaused = false;\n    if (_canPlay) unawaited(_resumePlayback());\n  }""",
    """  void _resumeAfterListingPreview() {\n    if (!_externallyPaused) return;\n    if (mounted) {\n      setState(() => _externallyPaused = false);\n    } else {\n      _externallyPaused = false;\n    }\n    if (_canPlay) unawaited(_resumePlayback());\n  }""",
    'Events resume hook keeps icon in sync',
)

old_toggle = """  void _toggleVideoPreview() {\n    AppHaptics.selection();\n    final next = !_videoPreviewEnabled;\n\n    // An explicit Play tap must reclaim Events playback immediately. A listing\n    // preview can leave this card externally paused; if that flag survives the\n    // user's tap, _canPlay stays false and the first tap only changes the icon.\n    if (next) _externallyPaused = false;\n    setState(() => _videoPreviewEnabled = next);\n\n    if (!next) {"""
new_toggle = """  void _toggleVideoPreview() {\n    AppHaptics.selection();\n\n    // If a listing owns playback, the Events control must LOOK like Play and\n    // one tap must reclaim playback immediately. Do not make the first tap only\n    // flip an internal flag while the movie remains paused.\n    if (_externallyPaused) {\n      setState(() {\n        _externallyPaused = false;\n        _videoPreviewEnabled = true;\n      });\n      unawaited(_resumePlayback());\n      final videos = _videos;\n      if (videos.length > 1) unawaited(_preloadNext(videos));\n      return;\n    }\n\n    final next = !_videoPreviewEnabled;\n    setState(() => _videoPreviewEnabled = next);\n\n    if (!next) {"""
s = replace_once(
    s,
    old_toggle,
    new_toggle,
    'one Events Play tap reclaims dashboard playback',
)

s = replace_once(
    s,
    """                      _videoPreviewEnabled\n                          ? Icons.pause_rounded\n                          : Icons.play_arrow_rounded,""",
    """                      (_videoPreviewEnabled && !_externallyPaused)\n                          ? Icons.pause_rounded\n                          : Icons.play_arrow_rounded,""",
    'Events icon shows Play while a listing owns playback',
)

p.write_text(s)


# ---------------------------------------------------------------------------
# WHITE/LIGHT AS THE FIRST DEFAULT APPEARANCE FOR THIS RELEASE
# ---------------------------------------------------------------------------
p = Path('lib/src/core/providers/visual_theme_provider.dart')
s = p.read_text()

s = replace_once(
    s,
    """class VisualThemeNotifier extends Notifier<AppVisualTheme> {\n  static const _prefsKey = 'swipess_visual_theme';""",
    """class VisualThemeNotifier extends Notifier<AppVisualTheme> {\n  static const _prefsKey = 'swipess_visual_theme';\n  static const _whiteDefaultMigrationKey =\n      'swipess_white_default_20260905_applied';""",
    'add one-time white-default migration marker',
)

old_hydrate = """  Future<void> _hydrate() async {\n    final prefs = await SharedPreferences.getInstance();\n    final raw = prefs.getString(_prefsKey);\n    final savedTheme = switch (raw) {\n      'dark' => AppVisualTheme.dark,\n      'light' => AppVisualTheme.light,\n      _ => null,\n    };\n    if (savedTheme != null && state != savedTheme) {\n      state = savedTheme;\n    }\n  }"""
new_hydrate = """  Future<void> _hydrate() async {\n    final prefs = await SharedPreferences.getInstance();\n\n    // Previous releases could leave existing installs persisted as dark even\n    // though white is now the product default. Migrate every install to white\n    // exactly once. After this marker is written, any user who intentionally\n    // switches to black/dark keeps that choice normally.\n    final migrated = prefs.getBool(_whiteDefaultMigrationKey) ?? false;\n    if (!migrated) {\n      await prefs.setString(_prefsKey, 'light');\n      await prefs.setBool(_whiteDefaultMigrationKey, true);\n      if (state != AppVisualTheme.light) state = AppVisualTheme.light;\n      return;\n    }\n\n    final raw = prefs.getString(_prefsKey);\n    final savedTheme = switch (raw) {\n      'dark' => AppVisualTheme.dark,\n      'light' => AppVisualTheme.light,\n      _ => null,\n    };\n    if (savedTheme != null && state != savedTheme) {\n      state = savedTheme;\n    }\n  }"""
s = replace_once(
    s,
    old_hydrate,
    new_hydrate,
    'force white once then preserve explicit dark preference',
)

p.write_text(s)

print('Quick-filter playback ownership + white-default repair applied.')
