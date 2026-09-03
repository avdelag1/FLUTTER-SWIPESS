from pathlib import Path

# Fix int typing around clamp and make the shared media turn impossible to get
# stuck when a video fails, is manually paused, scrolls away, or the card is
# disposed while it owns the turn.
provider = Path('lib/src/features/dashboard/presentation/providers/quick_filter_rotate_provider.dart')
text = provider.read_text()
text = text.replace('final count = slotCount.clamp(1, 64);', 'final count = slotCount.clamp(1, 64).toInt();')
provider.write_text(text)

media = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = media.read_text()
text = text.replace(
    'int get _rotateSlotCount => widget.slotCount.clamp(1, 64);',
    'int get _rotateSlotCount => widget.slotCount.clamp(1, 64).toInt();',
)

old = """    if (player.value.isPlaying) {\n      player.pause();\n      setState(() => _userPaused = true);\n      return;\n    }"""
new = """    if (player.value.isPlaying) {\n      player.pause();\n      setState(() => _userPaused = true);\n      // A manual pause must not freeze the whole dashboard forever.\n      ref.read(quickFilterRotateTickProvider.notifier).resumeStillWindow(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n      return;\n    }"""
assert old in text
text = text.replace(old, new, 1)

old = """    } else {\n      _pauseForCoordinator();\n    }\n\n    if (fraction <= 0.02 && _video != null) {"""
new = """    } else {\n      _pauseForCoordinator();\n      // If the active movie scrolls mostly off screen, release its video hold\n      // and use the normal still window so the sequence can keep progressing.\n      ref.read(quickFilterRotateTickProvider.notifier).resumeStillWindow(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n    }\n\n    if (fraction <= 0.02 && _video != null) {"""
assert old in text
text = text.replace(old, new, 1)

old = """  @override\n  void dispose() {\n    WidgetsBinding.instance.removeObserver(this);\n    _scrollPosition?.removeListener(_scheduleVisibilityCheck);\n    _VideoPlaybackCoordinator.unregisterHandoffState(this);\n    _VideoPlaybackCoordinator.release(this);\n    _disposeVideo();\n    super.dispose();\n  }"""
new = """  @override\n  void dispose() {\n    WidgetsBinding.instance.removeObserver(this);\n    _scrollPosition?.removeListener(_scheduleVisibilityCheck);\n    _VideoPlaybackCoordinator.unregisterHandoffState(this);\n    _VideoPlaybackCoordinator.release(this);\n    if (_ownsRotateTurn) {\n      ref.read(quickFilterRotateTickProvider.notifier).resumeStillWindow(\n            slot: widget.rotateSlot,\n            slotCount: _rotateSlotCount,\n          );\n    }\n    _disposeVideo();\n    super.dispose();\n  }"""
assert old in text
text = text.replace(old, new, 1)

old = """    } catch (_) {\n      if (identical(_video, next)) {\n        _video = null;\n        _boundVideoUrl = null;\n      }\n      if (_holdsBudgetSlot) {\n        _VideoBudget.release();\n        _holdsBudgetSlot = false;\n      }\n      if (mounted) setState(() {});"""
new = """    } catch (_) {\n      if (identical(_video, next)) {\n        _video = null;\n        _boundVideoUrl = null;\n      }\n      if (_holdsBudgetSlot) {\n        _VideoBudget.release();\n        _holdsBudgetSlot = false;\n      }\n      if (_ownsRotateTurn) {\n        ref.read(quickFilterRotateTickProvider.notifier).resumeStillWindow(\n              slot: widget.rotateSlot,\n              slotCount: _rotateSlotCount,\n            );\n      }\n      if (mounted) setState(() {});"""
assert old in text
text = text.replace(old, new, 1)

media.write_text(text)
print('Dashboard sequential media stabilization applied.')
