from pathlib import Path

p = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
s = p.read_text()
old = """      _attachPlayerListener(next);\n      if (autoPlay) {\n        if (!_VideoPlaybackCoordinator.owns(this)) {\n          _VideoPlaybackCoordinator.activate(this, _visibleFraction);\n        }\n        await _playIfReady();\n      }"""
new = """      _attachPlayerListener(next);\n      // A user can press Play while the paused warm-up controller is still\n      // initializing. In that race, the tap's _syncVideo(autoPlay: true) call\n      // sees _binding and returns, so the ORIGINAL warm-up future must notice\n      // the accepted manual play intent and start the movie as soon as init\n      // finishes. This is what makes one tap deterministic.\n      final shouldPlayNow =\n          autoPlay ||\n          (_manualPlaybackStarted &&\n              !_userPaused &&\n              _VideoPlaybackCoordinator.owns(this));\n      if (shouldPlayNow) {\n        if (!_VideoPlaybackCoordinator.owns(this)) {\n          _VideoPlaybackCoordinator.activate(this, _visibleFraction);\n        }\n        await _playIfReady();\n      }"""
if new in s:
    print('first-tap binding race: already applied')
elif old in s:
    p.write_text(s.replace(old, new, 1))
    print('first-tap binding race: patched')
else:
    raise SystemExit('first-tap binding race marker not found')
