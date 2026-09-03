from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing patch anchor: {label}")
    return text.replace(old, new, 1)


# Quick-filter listing videos: recognize explicit listing video URLs, keep
# exactly one dashboard video playing, and hand off the exact initialized
# controller/position to the swipe deck.
p = Path("lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart")
s = p.read_text()
s = s.replace("import 'package:flutter/services.dart';\n", "")

anchor = """bool isQuickFilterVideoUrl(String url) {
  final lower = url.toLowerCase();
  if (lower == 'video_attachment') return true;
  return lower.contains('.mp4') ||
      lower.contains('.webm') ||
      lower.contains('.mov') ||
      lower.contains('.m4v') ||
      lower.contains('/videos/');
}
"""
addition = anchor + """
VoidCallback? _pauseDashboardEventsPreview;
VoidCallback? _resumeDashboardEventsPreview;

/// Events owns the default live dashboard player. Listing quick filters can
/// temporarily take that playback slot without allowing two videos to run at
/// once. The hooks stay in-memory only and are cleared with the widget.
void registerDashboardEventsPlaybackHooks({
  required VoidCallback pause,
  required VoidCallback resume,
}) {
  _pauseDashboardEventsPreview = pause;
  _resumeDashboardEventsPreview = resume;
}

void unregisterDashboardEventsPlaybackHooks({
  required VoidCallback pause,
  required VoidCallback resume,
}) {
  if (identical(_pauseDashboardEventsPreview, pause)) {
    _pauseDashboardEventsPreview = null;
  }
  if (identical(_resumeDashboardEventsPreview, resume)) {
    _resumeDashboardEventsPreview = null;
  }
}
"""
if "_pauseDashboardEventsPreview" not in s:
    s = replace_once(s, anchor, addition, "dashboard event playback hooks")

old = """  static bool activate(_QuickFilterMediaState state, double visibility) {
    _activeStates.add(state);
    return true;
  }

  static bool owns(_QuickFilterMediaState state) =>
      _activeStates.contains(state);

  static void release(_QuickFilterMediaState state) {
    _activeStates.remove(state);
  }

  static void pauseActive() {
    final active = List<_QuickFilterMediaState>.of(_activeStates);
    _activeStates.clear();
    for (final state in active) {
      state._pauseForCoordinator(releaseOwnership: false);
    }
  }
"""
new = """  static bool activate(_QuickFilterMediaState state, double visibility) {
    // A dashboard can show several video-capable cards at once, but only one
    // controller may advance frames. A deliberate Play immediately silences
    // the previous listing card and the continuously-running Events teaser.
    final previous = List<_QuickFilterMediaState>.of(_activeStates);
    for (final candidate in previous) {
      if (identical(candidate, state)) continue;
      candidate._pauseForCoordinator(releaseOwnership: false);
    }
    _activeStates
      ..clear()
      ..add(state);
    _pauseDashboardEventsPreview?.call();
    return true;
  }

  static bool owns(_QuickFilterMediaState state) =>
      _activeStates.contains(state);

  static void release(
    _QuickFilterMediaState state, {
    bool resumeEventsWhenIdle = true,
  }) {
    _activeStates.remove(state);
    if (resumeEventsWhenIdle && _activeStates.isEmpty) {
      _resumeDashboardEventsPreview?.call();
    }
  }

  static void pauseActive({bool resumeEventsWhenIdle = false}) {
    final active = List<_QuickFilterMediaState>.of(_activeStates);
    _activeStates.clear();
    for (final state in active) {
      state._pauseForCoordinator(releaseOwnership: false);
    }
    if (resumeEventsWhenIdle) _resumeDashboardEventsPreview?.call();
  }
"""
if old in s:
    s = s.replace(old, new, 1)
elif "resumeEventsWhenIdle" not in s:
    raise SystemExit("missing patch anchor: exclusive quick filter playback")

old = """  bool get _hasVideo => _pool.any(isQuickFilterVideoUrl);

  int get _rotateSlotCount => widget.slotCount.clamp(1, 64).toInt();

  bool get _ownsRotateTurn {
    final tick = ref.read(quickFilterRotateTickProvider);
    final normalizedSlot = widget.rotateSlot % _rotateSlotCount;
    return tick % _rotateSlotCount ==
        (normalizedSlot < 0
            ? normalizedSlot + _rotateSlotCount
            : normalizedSlot);
  }
"""
new = """  bool _isKnownVideoUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return false;
    // `videoUrl` is authoritative. Supabase/CDN URLs are not required to keep
    // a file extension, so never demote a real uploaded movie to an image just
    // because its public URL is extensionless.
    for (final url in widget.sourceListingIds.keys) {
      if (url.trim() == normalized) return true;
    }
    return isQuickFilterVideoUrl(normalized);
  }

  bool get _hasVideo => _pool.any(_isKnownVideoUrl);

  int get _rotateSlotCount => widget.slotCount.clamp(1, 64).toInt();
"""
if old in s:
    s = s.replace(old, new, 1)
elif "bool _isKnownVideoUrl" not in s:
    raise SystemExit("missing patch anchor: quick filter video recognition")

s = s.replace(".where((u) => !isQuickFilterVideoUrl(u))", ".where((u) => !_isKnownVideoUrl(u))")
s = s.replace("if (!isQuickFilterVideoUrl(current))", "if (!_isKnownVideoUrl(current))")
s = s.replace("indexWhere(isQuickFilterVideoUrl)", "indexWhere(_isKnownVideoUrl)")
s = s.replace("!isQuickFilterVideoUrl(current)", "!_isKnownVideoUrl(current)")
s = s.replace("if (!isQuickFilterVideoUrl(url))", "if (!_isKnownVideoUrl(url))")
s = s.replace("!isQuickFilterVideoUrl(url)", "!_isKnownVideoUrl(url)")

handoff_release = """    _VideoPlaybackCoordinator.release(this);
    _VideoPlaybackCoordinator.pauseActive();
"""
handoff_release_new = """    _VideoPlaybackCoordinator.release(
      this,
      resumeEventsWhenIdle: false,
    );
    _VideoPlaybackCoordinator.pauseActive();
"""
if handoff_release in s:
    s = s.replace(handoff_release, handoff_release_new, 1)
p.write_text(s)


# Shared swipe stack: trust Listing.videoUrl instead of guessing from file
# extensions, so a dashboard controller can be adopted at its exact timestamp.
p = Path("lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart")
s = p.read_text()
old = """  bool _isVideoUrl(String value) {
    final l = value.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('/videos/');
  }

  String? _listingPrimaryVideo(Listing listing) {
    final media = <String>[...listing.images];
    final video = listing.videoUrl?.trim();
    if (video != null && video.isNotEmpty && !media.contains(video)) {
      media.insert(0, video);
    }
    for (final url in media) {
      if (_isVideoUrl(url)) return url;
    }
    return null;
  }
"""
new = """  bool _isVideoUrl(String value) {
    final l = value.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('.m4v') ||
        l.contains('/videos/');
  }

  String? _listingPrimaryVideo(Listing listing) {
    final explicit = listing.videoUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    for (final raw in listing.images) {
      final url = raw.trim();
      if (url.isNotEmpty && _isVideoUrl(url)) return url;
    }
    return null;
  }
"""
s = replace_once(s, old, new, "swipe stack explicit video")
old = """  String? _listingHeroImage(Listing listing) {
    for (final raw in listing.images) {
      final url = raw.trim();
      if (url.isNotEmpty && !_isVideoUrl(url)) return url;
    }
    return listing.images.isNotEmpty ? listing.images.first.trim() : null;
  }
"""
new = """  String? _listingHeroImage(Listing listing) {
    final explicitVideo = listing.videoUrl?.trim();
    for (final raw in listing.images) {
      final url = raw.trim();
      if (url.isEmpty || url == explicitVideo || _isVideoUrl(url)) continue;
      return url;
    }
    return null;
  }
"""
s = replace_once(s, old, new, "swipe stack hero image")
p.write_text(s)


# Swipe card: the explicit listing video is always a video, even when the CDN
# URL is extensionless. Remove stale helpers in this touched file.
p = Path("lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart")
s = p.read_text()
s = s.replace("import 'dart:ui';\n", "")
old = """  bool _isVideo(String value) {
    final l = value.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('/videos/');
  }

  bool get _needsVideo => widget.isTop;
"""
new = """  bool _isVideo(String value) {
    final normalized = value.trim();
    final explicit = widget.listing.videoUrl?.trim();
    if (explicit != null && explicit.isNotEmpty && normalized == explicit) {
      return true;
    }
    final l = normalized.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('.m4v') ||
        l.contains('/videos/');
  }
"""
s = replace_once(s, old, new, "swipe card explicit video")
s = s.replace("""  String? _posterUrl() {
    for (final url in _media) {
      if (!_isVideo(url)) return url;
    }
    return null;
  }

""", "", 1)
s = s.replace("""  Widget _videoPoster() {
    final poster = _posterUrl();
    if (poster == null) return _fallback();
    return _cachedCoverImage(poster);
  }

""", "", 1)
p.write_text(s)


# Deck opener: never image-precache the authoritative video URL and recognize
# m4v too.
p = Path("lib/src/features/swipes/presentation/utils/open_swipe_deck.dart")
s = p.read_text()
s = s.replace("""  return l.contains('.mp4') ||
      l.contains('.webm') ||
      l.contains('.mov') ||
      l.contains('/videos/');
""", """  return l.contains('.mp4') ||
      l.contains('.webm') ||
      l.contains('.mov') ||
      l.contains('.m4v') ||
      l.contains('/videos/');
""", 1)
old = """String? _listingHeroImage(Listing listing) {
  for (final raw in listing.images) {
    final url = raw.trim();
    if (url.isNotEmpty && !_isVideoUrl(url)) return url;
  }
  return listing.images.isNotEmpty ? listing.images.first.trim() : null;
}
"""
new = """String? _listingHeroImage(Listing listing) {
  final explicitVideo = listing.videoUrl?.trim();
  for (final raw in listing.images) {
    final url = raw.trim();
    if (url.isEmpty || url == explicitVideo || _isVideoUrl(url)) continue;
    return url;
  }
  return null;
}
"""
s = replace_once(s, old, new, "deck opener hero image")
p.write_text(s)


# Events joins the same single-player dashboard rule. Events remains the
# default autoplay surface; a user-started listing video temporarily owns the
# playback slot and Events resumes when it is released.
p = Path("lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart")
s = p.read_text()
import_anchor = "import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';\n"
if "quick_filter_media.dart" not in s:
    s = replace_once(
        s,
        import_anchor,
        import_anchor
        + "import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';\n",
        "events quick filter import",
    )
s = replace_once(
    s,
    "  bool _mediaUnlocked = false;\n  double _dragDx = 0;\n\n  bool get _canPlay => _routeActive && _appActive && _videoPreviewEnabled;\n",
    "  bool _mediaUnlocked = false;\n  bool _externallyPaused = false;\n  double _dragDx = 0;\n\n  bool get _canPlay =>\n      _routeActive && _appActive && _videoPreviewEnabled && !_externallyPaused;\n",
    "events external pause state",
)
s = replace_once(
    s,
    """    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
""",
    """    WidgetsBinding.instance.addObserver(this);
    registerDashboardEventsPlaybackHooks(
      pause: _pauseForListingPreview,
      resume: _resumeAfterListingPreview,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
""",
    "events register playback hooks",
)
s = replace_once(
    s,
    """    WidgetsBinding.instance.removeObserver(this);
    _current?.dispose();
""",
    """    WidgetsBinding.instance.removeObserver(this);
    unregisterDashboardEventsPlaybackHooks(
      pause: _pauseForListingPreview,
      resume: _resumeAfterListingPreview,
    );
    _current?.dispose();
""",
    "events unregister playback hooks",
)
method_anchor = "  Future<VideoPlayerController?> _prepare(Event event) async {\n"
methods = """  void _pauseForListingPreview() {
    if (_externallyPaused) return;
    _externallyPaused = true;
    final current = _current;
    if (current != null) {
      unawaited(() async {
        try {
          await current.setVolume(0);
          if (current.value.isPlaying) await current.pause();
        } catch (_) {}
      }());
    }
    unawaited(_preloaded?.pause() ?? Future<void>.value());
  }

  void _resumeAfterListingPreview() {
    if (!_externallyPaused) return;
    _externallyPaused = false;
    if (_routeActive && _appActive && _videoPreviewEnabled) {
      unawaited(_resumePlayback());
    }
  }

""" + method_anchor
if "void _pauseForListingPreview()" not in s:
    s = replace_once(s, method_anchor, methods, "events playback hook methods")
p.write_text(s)


# Event detail uses the authoritative event video URL too.
p = Path("lib/src/features/events/presentation/screens/event_detail_screen.dart")
s = p.read_text()
old = """  bool _isVideo(String url) {
    final l = url.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('/videos/');
  }
"""
new = """  bool _isVideo(String url) {
    final normalized = url.trim();
    final explicit = event.videoUrl?.trim();
    if (explicit != null && explicit.isNotEmpty && normalized == explicit) {
      return true;
    }
    final l = normalized.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('.m4v') ||
        l.contains('/videos/');
  }
"""
s = replace_once(s, old, new, "event detail video recognition")
p.write_text(s)
