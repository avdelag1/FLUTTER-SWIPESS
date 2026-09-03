from pathlib import Path

p = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
s = p.read_text()

old = """          child: PointerInterceptor(\n            intercepting: kIsWeb && _isKnownVideoUrl(current),\n            child: Row(\n"""
new = """          child: PointerInterceptor(\n            // Keep one stable web hit shield for every quick-filter media state.\n            // Toggling the interceptor only when a video appeared allowed the\n            // underlying HtmlElementView to win the pointer arena during the\n            // same frame that photo/video media changed. A permanent web\n            // interceptor makes left/center/right taps identical for photos and\n            // videos in installed PWAs and browser tabs.\n            intercepting: kIsWeb,\n            child: Row(\n"""
if old not in s:
    raise SystemExit('pointer interceptor anchor not found')
s = s.replace(old, new, 1)

old = """    if (ended && _manualPlaybackStarted && !_reportedVideoTurnComplete) {\n      _reportedVideoTurnComplete = true;\n      _manualPlaybackStarted = false;\n      _userPaused = true;\n      ref\n          .read(quickFilterRotateTickProvider.notifier)\n          .resumeAfterManualVideo(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n      _VideoPlaybackCoordinator.release(this);\n    }\n"""
new = """    if (ended && _manualPlaybackStarted && !_reportedVideoTurnComplete) {\n      _reportedVideoTurnComplete = true;\n      _manualPlaybackStarted = false;\n      _userPaused = true;\n      ref\n          .read(quickFilterRotateTickProvider.notifier)\n          .resumeAfterManualVideo(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n      _VideoPlaybackCoordinator.release(this);\n\n      // A dashboard preview is one shot: when it ends, move exactly one item\n      // forward and leave that next photo/video PAUSED as the new preview. Do\n      // this after the player callback returns so disposing the finished web\n      // HtmlElementView/controller cannot race its own listener notification.\n      WidgetsBinding.instance.addPostFrameCallback((_) {\n        if (!mounted || !_routeActive || _sources.length <= 1) return;\n        _advance(1);\n      });\n    }\n"""
if old not in s:
    raise SystemExit('video end anchor not found')
s = s.replace(old, new, 1)

p.write_text(s)
