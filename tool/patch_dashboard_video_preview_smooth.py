from pathlib import Path


PATH = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
s = PATH.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global s
    if old not in s:
        raise RuntimeError(f'missing patch target: {label}')
    s = s.replace(old, new, 1)


replace_once(
    """class _VideoBudget {\n  static const int maxActive = 10;\n  static int _active = 0;\n\n  static bool tryAcquire() {\n    if (_active >= maxActive) return false;\n    _active++;\n    return true;\n  }\n\n  static void release() {\n    if (_active > 0) _active--;\n  }\n}\n""",
    """class _VideoBudget {\n  // Keep decoder pressure deliberately tiny. Events has its own live player,\n  // so letting ten listing controllers sit around was enough to make web/PWA\n  // and older phones stutter badly. Two web previews / three native previews\n  // are enough to show real paused frames without turning the dashboard into a\n  // wall of active decoders.\n  static int get maxActive => kIsWeb ? 2 : 3;\n  static final Set<_QuickFilterMediaState> _holders =\n      <_QuickFilterMediaState>{};\n\n  static bool tryAcquire(\n    _QuickFilterMediaState state, {\n    bool priority = false,\n  }) {\n    if (_holders.contains(state)) return true;\n\n    // A user pressing Play always wins over an idle preview. Evict one paused\n    // preview instead of making the tap appear broken because the tiny decoder\n    // budget happened to be full.\n    if (_holders.length >= maxActive && priority) {\n      final candidates = List<_QuickFilterMediaState>.of(_holders);\n      for (final candidate in candidates) {\n        if (candidate._manualPlaybackStarted ||\n            _VideoPlaybackCoordinator.owns(candidate)) {\n          continue;\n        }\n        candidate._disposeVideo();\n        break;\n      }\n    }\n\n    if (_holders.length >= maxActive) return false;\n    _holders.add(state);\n    return true;\n  }\n\n  static void release(_QuickFilterMediaState state) {\n    _holders.remove(state);\n  }\n}\n""",
    'decoder budget',
)

replace_once(
    """  bool _visibilityCheckScheduled = false;\n""",
    """  bool _visibilityCheckScheduled = false;\n  bool _previewWarmupScheduled = false;\n\n  double get _previewWarmupThreshold => kIsWeb ? 0.42 : 0.28;\n""",
    'preview warmup state',
)

replace_once(
    """    // Listing videos are manual-only. Keep the poster visible and avoid any\n    // network video initialization until the user explicitly presses Play.\n    if (!_manualPlaybackStarted || _userPaused) {\n      _pauseForCoordinator();\n      return;\n    }\n\n    if (_visibleFraction >= 0.50) {\n""",
    """    // Non-Events videos remain manual-only, but a visible video listing now\n    // warms one paused controller so the card shows the REAL decoded movie\n    // frame instead of looking like another photo. This also makes Play feel\n    // instant because initialization has already happened.\n    if (!_manualPlaybackStarted || _userPaused) {\n      if (_visibleFraction >= _previewWarmupThreshold) {\n        _schedulePreviewWarmup();\n      } else if (_visibleFraction <= 0.06 && _video != null) {\n        // Release decoders as soon as a card is truly off-screen. This is the\n        // main guardrail that keeps scrolling and Events playback smooth.\n        _disposeVideo();\n      } else {\n        final player = _video;\n        if (player != null && player.value.isInitialized) {\n          unawaited(player.setVolume(0));\n          if (player.value.isPlaying) unawaited(player.pause());\n        }\n        _VideoPlaybackCoordinator.release(this);\n      }\n      return;\n    }\n\n    if (_visibleFraction >= 0.50) {\n""",
    'real paused video preview',
)

replace_once(
    """  void _pauseForCoordinator({bool releaseOwnership = true}) {\n""",
    """  void _schedulePreviewWarmup() {\n    if (!mounted ||\n        _previewWarmupScheduled ||\n        _binding ||\n        _video != null ||\n        !_routeActive ||\n        !_appActive) {\n      return;\n    }\n\n    _previewWarmupScheduled = true;\n    final stagger = widget.rotateSlot.abs() % 4;\n    final delay = Duration(\n      milliseconds: (kIsWeb ? 120 : 55) + stagger * (kIsWeb ? 55 : 28),\n    );\n\n    Future<void>.delayed(delay, () async {\n      _previewWarmupScheduled = false;\n      if (!mounted ||\n          !_routeActive ||\n          !_appActive ||\n          _manualPlaybackStarted ||\n          !_userPaused ||\n          _visibleFraction < _previewWarmupThreshold ||\n          _sources.isEmpty) {\n        return;\n      }\n      final current = _sources[_index % _sources.length];\n      if (!isQuickFilterVideoUrl(current)) return;\n      await _syncVideo(autoPlay: false);\n    });\n  }\n\n  void _pauseForCoordinator({bool releaseOwnership = true}) {\n""",
    'preview warmup helper',
)

replace_once(
    """      _VideoBudget.release();\n      _holdsBudgetSlot = false;\n""",
    """      _VideoBudget.release(this);\n      _holdsBudgetSlot = false;\n""",
    'handoff budget release',
)

replace_once(
    """      _VideoBudget.release();\n      _holdsBudgetSlot = false;\n""",
    """      _VideoBudget.release(this);\n      _holdsBudgetSlot = false;\n""",
    'dispose budget release',
)

replace_once(
    """    _reportedVideoTurnComplete = false;\n  }\n\n  Widget _mediaControlButton({\n""",
    """    _reportedVideoTurnComplete = false;\n    _previewWarmupScheduled = false;\n  }\n\n  Widget _mediaControlButton({\n""",
    'reset preview scheduler',
)

replace_once(
    """    if (!_holdsBudgetSlot && !_VideoBudget.tryAcquire()) return;\n""",
    """    if (!_holdsBudgetSlot &&\n        !_VideoBudget.tryAcquire(\n          this,\n          priority: autoPlay || _manualPlaybackStarted,\n        )) {\n      return;\n    }\n""",
    'priority decoder acquisition',
)

replace_once(
    """        _VideoBudget.release();\n        _holdsBudgetSlot = false;\n""",
    """        _VideoBudget.release(this);\n        _holdsBudgetSlot = false;\n""",
    'sync failure budget release',
)

# Make the current video unmistakable as a video even during the brief poster ->
# decoded-frame warmup. The actual Play control remains in the bottom-right.
replace_once(
    """        if (widget.showMute || (widget.enableVideo && _hasVideo))\n          Positioned(\n            bottom: 6,\n            right: 6,\n""",
    """        if (isQuickFilterVideoUrl(current))\n          Positioned(\n            bottom: 76,\n            right: 6,\n            child: IgnorePointer(\n              child: Container(\n                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),\n                decoration: BoxDecoration(\n                  color: Colors.black.withAlpha(145),\n                  borderRadius: BorderRadius.circular(999),\n                  border: Border.all(color: Colors.white.withAlpha(42)),\n                ),\n                child: const Row(\n                  mainAxisSize: MainAxisSize.min,\n                  children: [\n                    Icon(Icons.videocam_rounded, color: Colors.white, size: 12),\n                    SizedBox(width: 4),\n                    Text(\n                      'VIDEO',\n                      style: TextStyle(\n                        color: Colors.white,\n                        fontSize: 8,\n                        fontWeight: FontWeight.w900,\n                        letterSpacing: .7,\n                      ),\n                    ),\n                  ],\n                ),\n              ),\n            ),\n          ),\n        if (widget.showMute || (widget.enableVideo && _hasVideo))\n          Positioned(\n            bottom: 6,\n            right: 6,\n""",
    'video identity badge',
)

PATH.write_text(s)
print('patched dashboard video previews and decoder budget')
