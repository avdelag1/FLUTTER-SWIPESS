from pathlib import Path

# Make parallel uploads observed as one Future.wait so one failed upload cannot
# leave another concurrent upload future unobserved.
p = Path('lib/src/features/add/presentation/providers/add_listing_provider.dart')
s = p.read_text()
old = """      final urls = await photosFuture;\n      final videoUrl = await videoFuture;\n      final backgroundMusicUrl = await musicFuture;\n      final payload = _payload(\n"""
new = """      final uploadedMedia = await Future.wait<Object?>([\n        photosFuture,\n        videoFuture,\n        musicFuture,\n      ]);\n      final urls = uploadedMedia[0] as List<String>;\n      final videoUrl = uploadedMedia[1] as String?;\n      final backgroundMusicUrl = uploadedMedia[2] as String?;\n      final payload = _payload(\n"""
if old not in s:
    raise RuntimeError('publish Future.wait target missing')
s = s.replace(old, new, 1)
p.write_text(s)

# Make the always-visible play control useful even when the current automatic
# preview is a photo: Play jumps to the first real video in that category. Also
# replay a video cleanly after it reaches the end.
p = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
s = p.read_text()
old = """  void _togglePlayPause() {\n    AppHaptics.selection();\n\n    final player = _video;\n"""
new = """  void _togglePlayPause() {\n    AppHaptics.selection();\n\n    if (_sources.isEmpty) return;\n    final current = _sources[_index % _sources.length];\n    if (!isQuickFilterVideoUrl(current)) {\n      final videoIndex = _sources.indexWhere(isQuickFilterVideoUrl);\n      if (videoIndex < 0) return;\n      _disposeVideo();\n      setState(() {\n        _index = videoIndex;\n        _reportedVideoTurnComplete = false;\n      });\n    }\n\n    final player = _video;\n"""
if old not in s:
    raise RuntimeError('play control target missing')
s = s.replace(old, new, 1)

old = """    try {\n      await player.setVolume(wantSound ? 1 : 0);\n      if (!_VideoPlaybackCoordinator.owns(this)) {\n"""
new = """    try {\n      final duration = player.value.duration;\n      final position = player.value.position;\n      if (duration.inMilliseconds > 0 &&\n          position.inMilliseconds >= duration.inMilliseconds - 180) {\n        await player.seekTo(Duration.zero);\n      }\n      await player.setVolume(wantSound ? 1 : 0);\n      if (!_VideoPlaybackCoordinator.owns(this)) {\n"""
if old not in s:
    raise RuntimeError('video replay target missing')
s = s.replace(old, new, 1)
p.write_text(s)

print('listing media controls finalized')
