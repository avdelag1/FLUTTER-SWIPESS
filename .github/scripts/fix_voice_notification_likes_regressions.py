from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


# 1) Native speech recognition: silence ends a platform recognition segment.
# Restarting immediately can produce iOS/Android busy/client errors while the
# 3-2-1 countdown is already visible. Those are recoverable session transitions.
voice_path = Path("lib/src/features/ai/presentation/services/live_voice_input.dart")
voice = voice_path.read_text()
voice = replace_once(
    voice,
    "  bool _nativeRestarting = false;\n  Object? _owner;",
    "  bool _nativeRestarting = false;\n  int _nativeTransientFailures = 0;\n  Object? _owner;",
    "voice transient failure field",
)
voice = replace_once(
    voice,
    "    _silenceDeliveredForSegment = false;\n    _intentionalStop = false;",
    "    _silenceDeliveredForSegment = false;\n    _nativeTransientFailures = 0;\n    _intentionalStop = false;",
    "voice session reset",
)
old_error = """      onError: (error) {
        if (!_active || _intentionalStop) return;
        final msg = error.errorMsg.toLowerCase();
        if (msg.contains('no_match') ||
            msg.contains('speech_timeout') ||
            msg.contains('timeout')) {
          _finishNativeSegmentAndRestart();
          return;
        }
        if (msg.contains('permission') || msg.contains('not authorized')) {
          _nativeInitialized = false;
          _onError?.call(
            'Microphone access is required. Open Settings → Swipess and allow Microphone and Speech Recognition.',
          );
          return;
        }
        _onError?.call('Voice recognition stopped. Please try again.');
      },"""
voice = replace_once(
    voice,
    old_error,
    "      onError: (error) => _handleNativeError(error.errorMsg),",
    "voice native error callback",
)
helper = """  void _handleNativeError(String rawMessage) {
    if (!_active || _intentionalStop || _usingBrowser) return;
    final msg = rawMessage.toLowerCase();

    if (msg.contains('no_match') ||
        msg.contains('speech_timeout') ||
        msg.contains('timeout')) {
      _finishNativeSegmentAndRestart(
        restartDelay: const Duration(milliseconds: 520),
      );
      return;
    }

    if (msg.contains('permission') || msg.contains('not authorized')) {
      _nativeInitialized = false;
      _onError?.call(
        'Microphone access is required. Open Settings → Swipess and allow Microphone and Speech Recognition.',
      );
      return;
    }

    const transientMarkers = <String>[
      'busy',
      'client',
      'network',
      'server',
      'audio',
      'recognizer',
      'retry',
      'temporarily',
    ];
    final recoverable =
        transientMarkers.any(msg.contains) || !_nativeSpeech.isListening;
    if (recoverable && _nativeTransientFailures < 4) {
      _nativeTransientFailures += 1;
      _finishNativeSegmentAndRestart(
        restartDelay: const Duration(milliseconds: 650),
      );
      return;
    }

    _onError?.call('Voice recognition stopped. Please try again.');
  }

"""
voice = replace_once(
    voice,
    "  Future<bool> _ensureNativePermission() async {",
    helper + "  Future<bool> _ensureNativePermission() async {",
    "voice error helper anchor",
)
voice = replace_once(
    voice,
    "    _nativeSessionText = speech;\n    _segmentHasSpeech = true;",
    "    _nativeSessionText = speech;\n    _segmentHasSpeech = true;\n    _nativeTransientFailures = 0;",
    "voice result recovery reset",
)
voice = replace_once(
    voice,
    "    if (normalized == stt.SpeechToText.listeningStatus.toLowerCase()) {\n      _publishListening(true);",
    "    if (normalized == stt.SpeechToText.listeningStatus.toLowerCase()) {\n      _nativeTransientFailures = 0;\n      _publishListening(true);",
    "voice listening recovery reset",
)
voice = replace_once(
    voice,
    "  void _finishNativeSegmentAndRestart() {",
    "  void _finishNativeSegmentAndRestart({\n    Duration restartDelay = const Duration(milliseconds: 520),\n  }) {",
    "voice restart signature",
)
voice = replace_once(
    voice,
    "    _nativeRestartTimer = Timer(const Duration(milliseconds: 180), () async {",
    "    _nativeRestartTimer = Timer(restartDelay, () async {",
    "voice restart delay",
)
old_start_failure = """    _onError?.call('Could not start listening. Tap the microphone again.');
    _clearSession(keepOwner: false);"""
new_start_failure = """    if (_nativeTransientFailures < 4) {
      _nativeTransientFailures += 1;
      _finishNativeSegmentAndRestart(
        restartDelay: const Duration(milliseconds: 650),
      );
      return;
    }

    _onError?.call('Could not start listening. Tap the microphone again.');
    _clearSession(keepOwner: false);"""
voice = replace_once(
    voice,
    old_start_failure,
    new_start_failure,
    "voice start retry",
)
voice_path.write_text(voice)

# 2) Notification permission: app backgrounding is never a user gesture.
notifications_path = Path("lib/src/core/native/local_notifications_service.dart")
notifications = notifications_path.read_text()
notifications = replace_once(
    notifications,
    "    await initialize();\n    if (!await ensurePermission()) return;\n    await cancelReengagement();",
    "    await initialize();\n    // Backgrounding the app must never open an OS permission prompt. Permission\n    // is requested only from an explicit foreground user action.\n    if (!_permissionGranted) return;\n    await cancelReengagement();",
    "background notification permission request",
)
notifications_path.write_text(notifications)

# 3) Likes are a universal discovery exclusion, including events.
likes_path = Path("lib/src/features/likes/presentation/providers/likes_provider.dart")
likes = likes_path.read_text()
old_events = """/// Events are intentionally persistent on the map. Unlike marketplace cards,
/// they are time-based context: saving an event should not erase it from the
/// geographic/event layer while it is still relevant.
final likedEventIdsProvider = FutureProvider<Set<String>>(
  (ref) async => const <String>{},
);"""
new_events = """/// Map discovery excludes every target already saved/right-swiped by the user,
/// including events. Likes is the source of truth across all discovery types.
final likedEventIdsProvider = FutureProvider<Set<String>>(
  (ref) => _fetchLikedTargetIds('event'),
);"""
likes = replace_once(likes, old_events, new_events, "liked event provider")
likes_path.write_text(likes)

map_path = Path("lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart")
map_src = map_path.read_text()
old_map_likes = """    final likedPeople =
        ref.read(likedPeopleIdsProvider).value ?? const <String>{};
    final likedEvents =
        ref.read(likedEventIdsProvider).value ?? const <String>{};
    return <_Item>[
          for (final l in listings)
            if (!listingLikesStillLoading && !likedListings.contains(l.id))
              _listingItem(l, loc),
          for (final p in profiles)
            if (!likedPeople.contains(p.id)) _profileItem(p, loc),
          for (final e in events)
            if (_eventInCity(e, loc) && !likedEvents.contains(e.id))
              _eventItem(e, loc),"""
new_map_likes = """    final likedPeopleIds = ref.read(likedPeopleIdsProvider);
    final likedPeopleModels = ref.read(likedPeopleProvider);
    final likedPeople = <String>{};
    likedPeople.addAll(likedPeopleIds.value ?? const <String>{});
    likedPeople.addAll(
      (likedPeopleModels.value ?? const <ProfileLike>[]).map((person) => person.userId),
    );
    final peopleLikesStillLoading =
        likedPeopleIds.isLoading &&
        !likedPeopleIds.hasValue &&
        !likedPeopleModels.hasValue;

    final likedEventIds = ref.read(likedEventIdsProvider);
    final likedEvents = likedEventIds.value ?? const <String>{};
    final eventLikesStillLoading =
        likedEventIds.isLoading && !likedEventIds.hasValue;

    return <_Item>[
          for (final l in listings)
            if (!listingLikesStillLoading && !likedListings.contains(l.id))
              _listingItem(l, loc),
          for (final p in profiles)
            if (!peopleLikesStillLoading && !likedPeople.contains(p.id))
              _profileItem(p, loc),
          for (final e in events)
            if (!eventLikesStillLoading &&
                _eventInCity(e, loc) &&
                !likedEvents.contains(e.id))
              _eventItem(e, loc),"""
map_src = replace_once(map_src, old_map_likes, new_map_likes, "map all-likes exclusion")
import_anchor = "import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';"
profile_like_import = "import 'package:flutter_swipes/src/features/likes/domain/profile_like.dart';"
if profile_like_import not in map_src:
    map_src = replace_once(
        map_src,
        import_anchor,
        profile_like_import + "\n" + import_anchor,
        "map ProfileLike import",
    )
map_path.write_text(map_src)

# 4) Persistent handoff instructions for future coding agents.
agents_path = Path("AGENTS.md")
agents = agents_path.read_text()
agents = agents.replace(
    "- Listings and people already right-swiped/saved by the current user must not reappear in Map discovery.",
    "- Listings, people, and events already right-swiped/saved by the current user must not reappear in Map discovery.",
)
agents = agents.replace(
    "- Do not paint discovery listings while canonical liked-listing state is unresolved if that can cause already-liked items to flash/reappear.",
    "- Do not paint any discovery type while its canonical Likes state is unresolved if that can cause already-liked items to flash/reappear.",
)
handoff = """### Voice countdown must survive native recognizer segment restarts
- Native speech engines may end/restart a recognition segment exactly when silence starts the dashboard **3 → 2 → 1** countdown.
- Busy/client/network/server/audio recognizer transition errors during that restart are recoverable. Retry them quietly with a short backoff; do **not** cancel the countdown or show `Voice recognition stopped` for a transient segment restart.
- Permission/authorization failures remain user-facing and fatal for that microphone session.
- Speaking again during the countdown must still cancel countdown and continue the same transcript.

### Notification permission is foreground-only
- `AppLifecycleState.paused`, backgrounding, app exit, and reengagement scheduling must **never request notification permission**.
- OS notification permission may only be requested after a clear foreground user action such as tapping an Enable notifications control.
- If permission is not already granted, background reengagement scheduling should quietly do nothing.

"""
verify_anchor = "### Verification before merging related work\n"
if "### Voice countdown must survive native recognizer segment restarts" not in agents:
    agents = replace_once(
        agents,
        verify_anchor,
        handoff + verify_anchor,
        "AGENTS handoff anchor",
    )
agents_path.write_text(agents)

assert "Duration restartDelay = const Duration(milliseconds: 520)" in voice
assert "Backgrounding the app must never open an OS permission prompt" in notifications
assert "_fetchLikedTargetIds('event')" in likes
assert "eventLikesStillLoading" in map_src
assert "peopleLikesStillLoading" in map_src
assert "Notification permission is foreground-only" in agents
