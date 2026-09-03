from pathlib import Path

quick = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = quick.read_text()

text = text.replace("import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';\n", "")

start = text.index('class _VideoPlaybackCoordinator {')
end = text.index('/// Called before opening another media surface', start)
new_coordinator = '''class _VideoPlaybackCoordinator {\n  // Manual quick-filter players are independent. Track every active card so\n  // one card's Play/Mute controls never change another card's media state.\n  static final Set<_QuickFilterMediaState> _activeStates =\n      <_QuickFilterMediaState>{};\n  static final Map<String, _QuickFilterMediaState> _handoffStates =\n      <String, _QuickFilterMediaState>{};\n\n  static void registerHandoffState(_QuickFilterMediaState state) {\n    final category = state.widget.handoffCategoryId;\n    if (category == null || category.isEmpty) return;\n    _handoffStates[category] = state;\n  }\n\n  static void unregisterHandoffState(\n    _QuickFilterMediaState state, {\n    String? category,\n  }) {\n    final key = category ?? state.widget.handoffCategoryId;\n    if (key == null || !identical(_handoffStates[key], state)) return;\n    _handoffStates.remove(key);\n  }\n\n  static bool activate(_QuickFilterMediaState state, double visibility) {\n    _activeStates.add(state);\n    return true;\n  }\n\n  static bool owns(_QuickFilterMediaState state) =>\n      _activeStates.contains(state);\n\n  static void release(_QuickFilterMediaState state) {\n    _activeStates.remove(state);\n  }\n\n  static void pauseActive() {\n    final active = List<_QuickFilterMediaState>.of(_activeStates);\n    _activeStates.clear();\n    for (final state in active) {\n      state._pauseForCoordinator(releaseOwnership: false);\n    }\n  }\n\n  static SwipeDeckMediaHandoffData? captureActiveForDeck({\n    String? categoryId,\n  }) {\n    if (categoryId != null) {\n      final targeted = _handoffStates[categoryId];\n      if (targeted == null) return null;\n      return targeted._captureForDeckHandoff(requireOwnership: false);\n    }\n\n    if (_activeStates.isEmpty) return null;\n    return _activeStates.last._captureForDeckHandoff();\n  }\n}\n\n'''
text = text[:start] + new_coordinator + text[end:]

old = '''SwipeDeckMediaHandoffData? captureQuickFilterVideoForDeck({\n  required bool wantSound,\n  String? categoryId,\n}) => _VideoPlaybackCoordinator.captureActiveForDeck(\n  wantSound,\n  categoryId: categoryId,\n);'''
new = '''SwipeDeckMediaHandoffData? captureQuickFilterVideoForDeck({\n  String? categoryId,\n}) => _VideoPlaybackCoordinator.captureActiveForDeck(\n  categoryId: categoryId,\n);'''
assert old in text
text = text.replace(old, new, 1)

old = '''  bool _reportedVideoTurnComplete = false;\n  double _visibleFraction = 0;'''
new = '''  bool _reportedVideoTurnComplete = false;\n  bool _soundOn = false;\n  bool _mediaUnlocked = false;\n  double _visibleFraction = 0;'''
assert old in text
text = text.replace(old, new, 1)

old = '''  void _toggleSound() {\n    AppHaptics.selection();\n    unlockDeckMedia();\n    final nextSoundOn = !ref.read(deckSoundOnProvider);\n    ref.read(deckSoundOnProvider.notifier).setSoundOn(nextSoundOn);\n    _onSoundChanged(nextSoundOn);\n  }'''
new = '''  void _toggleSound() {\n    AppHaptics.selection();\n    unlockDeckMedia();\n    final nextSoundOn = !_soundOn;\n    if (nextSoundOn) _mediaUnlocked = true;\n    setState(() => _soundOn = nextSoundOn);\n    _onSoundChanged(nextSoundOn);\n  }'''
assert old in text
text = text.replace(old, new, 1)

old = '''  SwipeDeckMediaHandoffData? _captureForDeckHandoff(\n    bool wantSound, {\n    bool requireOwnership = true,\n  }) {'''
new = '''  SwipeDeckMediaHandoffData? _captureForDeckHandoff({\n    bool requireOwnership = true,\n  }) {'''
assert old in text
text = text.replace(old, new, 1)

old = '''    if (_VideoPlaybackCoordinator.owns(this)) {\n      // Transfer the exact playing movie without pausing it.\n      _VideoPlaybackCoordinator.release(this);\n    } else {\n      // A different dashboard card may own audio. Silence it before the\n      // destination route starts, but keep this targeted decoded frame intact.\n      _VideoPlaybackCoordinator.pauseActive();\n    }'''
new = '''    // Transfer this exact movie, then stop every OTHER quick-filter player so\n    // no dashboard audio keeps running underneath the destination route.\n    _VideoPlaybackCoordinator.release(this);\n    _VideoPlaybackCoordinator.pauseActive();'''
assert old in text
text = text.replace(old, new, 1)

old = '''      wantSound: wantSound,\n      listingId: _listingIdForUrl(url),'''
new = '''      wantSound: _soundOn && (_mediaUnlocked || !kIsWeb),\n      listingId: _listingIdForUrl(url),'''
assert old in text
text = text.replace(old, new, 1)

old = '''    final soundOn = ref.read(deckSoundOnProvider);\n    final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;\n    final wantSound = soundOn && (unlocked || !kIsWeb);'''
new = '''    final wantSound = _soundOn && (_mediaUnlocked || !kIsWeb);'''
assert old in text
text = text.replace(old, new, 1)

old = '''      final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;\n      player.setVolume(soundOn && (unlocked || !kIsWeb) ? 1 : 0);'''
new = '''      player.setVolume(soundOn && (_mediaUnlocked || !kIsWeb) ? 1 : 0);'''
assert old in text
text = text.replace(old, new, 1)

old = '''    final soundOn = ref.watch(deckSoundOnProvider);\n    final player = _video;'''
new = '''    final soundOn = _soundOn;\n    final player = _video;'''
assert old in text
text = text.replace(old, new, 1)

old = '''    ref.listen<bool>(deckSoundOnProvider, (_, next) => _onSoundChanged(next));\n\n    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {'''
new = '''    ref.listen<int>(quickFilterRotateTickProvider, (prev, next) {'''
assert old in text
text = text.replace(old, new, 1)

assert 'deckSoundOnProvider' not in text
quick.write_text(text)

# Opening a category should use the quick-filter player's own sound state. The
# capture API no longer accepts the unrelated global deck sound preference.
open_deck = Path('lib/src/features/swipes/presentation/utils/open_swipe_deck.dart')
text = open_deck.read_text()
old = '''  final handoff = captureQuickFilterVideoForDeck(\n    wantSound: soundOn,\n    categoryId: categoryId,\n  );'''
new = '''  final handoff = captureQuickFilterVideoForDeck(\n    categoryId: categoryId,\n  );'''
assert old in text
text = text.replace(old, new, 1)
open_deck.write_text(text)

# Events is also a quick filter, so its dashboard mute/play controls must be
# local to Events rather than wired to the shared swipe-deck audio preference.
events = Path('lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart')
text = events.read_text()

old = '''  bool _videoPreviewEnabled = true;\n  double _dragDx = 0;'''
new = '''  bool _videoPreviewEnabled = true;\n  bool _soundOn = false;\n  bool _mediaUnlocked = false;\n  double _dragDx = 0;'''
assert old in text
text = text.replace(old, new, 1)

old = '''  Future<void> _applySound() async {\n    final current = _current;\n    if (current == null) return;\n    final soundOn = ref.read(deckSoundOnProvider);\n    final unlocked = ref.read(deckSoundOnProvider.notifier).mediaUnlocked;\n    final wantSound = soundOn && (unlocked || !kIsWeb);\n    try {\n      await current.setVolume(wantSound && _canPlay ? 1 : 0);\n    } catch (_) {}\n  }\n\n  void _toggleSound() {\n    AppHaptics.selection();\n    unlockDeckMedia();\n    final next = !ref.read(deckSoundOnProvider);\n    ref.read(deckSoundOnProvider.notifier).setSoundOn(next);\n    unawaited(_applySound());\n  }'''
new = '''  Future<void> _applySound() async {\n    final current = _current;\n    if (current == null) return;\n    final wantSound = _soundOn && (_mediaUnlocked || !kIsWeb);\n    try {\n      await current.setVolume(wantSound && _canPlay ? 1 : 0);\n    } catch (_) {}\n  }\n\n  void _toggleSound() {\n    AppHaptics.selection();\n    unlockDeckMedia();\n    final next = !_soundOn;\n    if (next) _mediaUnlocked = true;\n    setState(() => _soundOn = next);\n    unawaited(_applySound());\n  }'''
assert old in text
text = text.replace(old, new, 1)

old = '''    final soundOn = ref.read(deckSoundOnProvider);\n\n    // Keep web audio unlocked in the same tap gesture that opens Events.'''
new = '''    final soundOn = _soundOn;\n\n    // Keep web audio unlocked in the same tap gesture that opens Events.'''
assert old in text
text = text.replace(old, new, 1)

old = '''    final teaserAsync = ref.watch(dashboardVideoEventsProvider);\n    final videos = _uniqueVideos(teaserAsync.value ?? const <Event>[]);\n    final soundOn = ref.watch(deckSoundOnProvider);'''
new = '''    final teaserAsync = ref.watch(dashboardVideoEventsProvider);\n    final videos = _uniqueVideos(teaserAsync.value ?? const <Event>[]);\n    final soundOn = _soundOn;'''
assert old in text
text = text.replace(old, new, 1)

old = '''    ref.listen<bool>(deckSoundOnProvider, (_, __) => _applySound());\n\n    final safeIndex = videos.isEmpty ? 0 : _index % videos.length;'''
new = '''    final safeIndex = videos.isEmpty ? 0 : _index % videos.length;'''
assert old in text
text = text.replace(old, new, 1)

old = '''                  GestureDetector(\n                    onTap: _toggleSound,\n                    behavior: HitTestBehavior.opaque,\n                    child: Container(\n                      width: 30,\n                      height: 30,\n                      alignment: Alignment.center,\n                      decoration: BoxDecoration(\n                        color: Colors.black.withAlpha(132),\n                        shape: BoxShape.circle,\n                        border: Border.all(color: Colors.white.withAlpha(48)),\n                      ),\n                      child: Icon(\n                        soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,\n                        color: Colors.white,\n                        size: 16,\n                      ),\n                    ),\n                  ),'''
new = '''                  GestureDetector(\n                    onTap: _toggleSound,\n                    behavior: HitTestBehavior.opaque,\n                    child: Container(\n                      width: 30,\n                      height: 30,\n                      alignment: Alignment.center,\n                      decoration: BoxDecoration(\n                        color: Colors.black.withAlpha(132),\n                        shape: BoxShape.circle,\n                        border: Border.all(color: Colors.white.withAlpha(48)),\n                      ),\n                      child: Icon(\n                        soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,\n                        color: Colors.white,\n                        size: 16,\n                      ),\n                    ),\n                  ),\n                  const SizedBox(height: 6),\n                  GestureDetector(\n                    onTap: _toggleVideoPreview,\n                    behavior: HitTestBehavior.opaque,\n                    child: Container(\n                      width: 30,\n                      height: 30,\n                      alignment: Alignment.center,\n                      decoration: BoxDecoration(\n                        color: Colors.black.withAlpha(132),\n                        shape: BoxShape.circle,\n                        border: Border.all(color: Colors.white.withAlpha(48)),\n                      ),\n                      child: Icon(\n                        _videoPreviewEnabled\n                            ? Icons.pause_rounded\n                            : Icons.play_arrow_rounded,\n                        color: Colors.white,\n                        size: 16,\n                      ),\n                    ),\n                  ),'''
assert old in text
text = text.replace(old, new, 1)

events.write_text(text)
