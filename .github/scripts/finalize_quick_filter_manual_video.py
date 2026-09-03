from pathlib import Path

p = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
s = p.read_text()

old = """    _VideoPlaybackCoordinator.unregisterHandoffState(this);\n    _VideoPlaybackCoordinator.release(this);\n    if (_ownsRotateTurn) {\n      ref.read(quickFilterRotateTickProvider.notifier).resumeStillWindow(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n    }\n    _disposeVideo();\n"""
new = """    _VideoPlaybackCoordinator.unregisterHandoffState(this);\n    _VideoPlaybackCoordinator.release(this);\n    _disposeVideo();\n"""
if old not in s:
    raise RuntimeError('dispose target missing')
s = s.replace(old, new, 1)

old = """  void _pauseForCoordinator({bool releaseOwnership = true}) {\n    final player = _video;\n    if (player != null && player.value.isInitialized) {\n      unawaited(player.setVolume(0));\n      if (player.value.isPlaying) unawaited(player.pause());\n    }\n    if (releaseOwnership) _VideoPlaybackCoordinator.release(this);\n  }\n"""
new = """  void _pauseForCoordinator({bool releaseOwnership = true}) {\n    final player = _video;\n    if (player != null && player.value.isInitialized) {\n      unawaited(player.setVolume(0));\n      if (player.value.isPlaying) unawaited(player.pause());\n    }\n    if (_manualPlaybackStarted) {\n      _manualPlaybackStarted = false;\n      _userPaused = true;\n      ref.read(quickFilterRotateTickProvider.notifier).resumeAfterManualVideo(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n    }\n    if (releaseOwnership) _VideoPlaybackCoordinator.release(this);\n  }\n"""
if old not in s:
    raise RuntimeError('coordinator target missing')
s = s.replace(old, new, 1)

old = """  void _disposeVideo() {\n    _detachPlayerListener(_video);\n    _VideoPlaybackCoordinator.release(this);\n"""
new = """  void _disposeVideo() {\n    ref.read(quickFilterRotateTickProvider.notifier).resumeAfterManualVideo(\n          slot: widget.rotateSlot,\n          slotCount: _rotateSlotCount,\n        );\n    _detachPlayerListener(_video);\n    _VideoPlaybackCoordinator.release(this);\n"""
if old not in s:
    raise RuntimeError('dispose video target missing')
s = s.replace(old, new, 1)

p.write_text(s)
print('manual quick-filter lifecycle finalized')
