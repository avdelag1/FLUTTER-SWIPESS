from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 anchor, found {count}')
    return text.replace(old, new, 1)


# Riverpod 3 keeps StateProvider on its legacy compatibility surface.
path = Path('lib/src/core/providers/search_bar_slot_provider.dart')
text = path.read_text()
if 'StateProvider<Widget?>' in text and "package:flutter_riverpod/legacy.dart" not in text:
    text = text.replace(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
        "import 'package:flutter_riverpod/legacy.dart';",
        1,
    )
path.write_text(text)

# DashboardShell already requests compactHeader=true; complete the GlowSearchBar
# side so the persistent header stays one pill and opens Concierge for answers.
path = Path('lib/src/core/widgets/glow_search_bar.dart')
text = path.read_text()
text = replace_once(
    text,
    "    this.onGuestsTap,\n  });",
    "    this.onGuestsTap,\n    this.compactHeader = false,\n  });",
    'GlowSearchBar compact constructor',
)
text = replace_once(
    text,
    "  final VoidCallback? onGuestsTap;\n\n  @override",
    "  final VoidCallback? onGuestsTap;\n\n  /// Header mode keeps the AI control to one persistent pill.\n  final bool compactHeader;\n\n  @override",
    'GlowSearchBar compact field',
)
compact_submit = """    if (widget.compactHeader) {
      ref.read(overlayModalsProvider.notifier).openConcierge(input);
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    await _runInlineAi(input);"""
if compact_submit not in text:
    old = """    if (wantsExplicitNavigation(input) && _runDirectSearch(input)) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    await _runInlineAi(input);"""
    new = """    if (wantsExplicitNavigation(input) && _runDirectSearch(input)) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    if (widget.compactHeader) {
      ref.read(overlayModalsProvider.notifier).openConcierge(input);
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    await _runInlineAi(input);"""
    if old not in text:
        raise SystemExit('GlowSearchBar compact submit anchor missing')
    text = text.replace(old, new, 1)
old_panel = """          _inlineAiPanel(isLight: isLight, ink: ink, blue: blue),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Google Gemini · can make mistakes.',
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(isLight ? 135 : 170),
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
          ),"""
new_panel = """          if (!widget.compactHeader) ...[
            _inlineAiPanel(isLight: isLight, ink: ink, blue: blue),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Google Gemini · can make mistakes.',
                style: GoogleFonts.plusJakartaSans(
                  color: ink.withAlpha(isLight ? 135 : 170),
                  fontWeight: FontWeight.w500,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],"""
if new_panel not in text:
    if old_panel not in text:
        raise SystemExit('GlowSearchBar compact panel anchor missing')
    text = text.replace(old_panel, new_panel, 1)
path.write_text(text)

# Restore the missing playback coordinator API and preserve listing identity /
# poster alignment when quick-filter media is shuffled.
path = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = path.read_text()

if 'void pauseDashboardEventsPreviewForListing()' not in text:
    anchor = """void unregisterDashboardEventsPlaybackHooks({
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
    insert = anchor + """
void pauseDashboardEventsPreviewForListing() =>
    _pauseDashboardEventsPreview?.call();
void resumeDashboardEventsPreviewAfterListing() =>
    _resumeDashboardEventsPreview?.call();

final Set<VoidCallback> _pauseDedicatedListingPreviews = <VoidCallback>{};

void registerDedicatedListingPlaybackPause(VoidCallback pause) {
  _pauseDedicatedListingPreviews.add(pause);
}

void unregisterDedicatedListingPlaybackPause(VoidCallback pause) {
  _pauseDedicatedListingPreviews.remove(pause);
}

void pauseDedicatedListingVideoPlayback({VoidCallback? except}) {
  final pauses = List<VoidCallback>.of(_pauseDedicatedListingPreviews);
  for (final pause in pauses) {
    if (except != null && identical(pause, except)) continue;
    pause();
  }
}
"""
    if anchor not in text:
        raise SystemExit('dashboard playback hook anchor missing')
    text = text.replace(anchor, insert, 1)

activation = """    _activeStates
      ..clear()
      ..add(state);
    _pauseDashboardEventsPreview?.call();
    return true;
"""
activation_fixed = """    _activeStates
      ..clear()
      ..add(state);
    pauseDedicatedListingVideoPlayback();
    _pauseDashboardEventsPreview?.call();
    return true;
"""
if activation_fixed not in text:
    if activation not in text:
        raise SystemExit('quick-filter activation anchor missing')
    text = text.replace(activation, activation_fixed, 1)

if 'this.sourceListingIdsByIndex = const <String?>[],' not in text:
    anchor = '    this.enableVideo = true,\n'
    if text.count(anchor) != 1:
        raise SystemExit('QuickFilterMedia constructor anchor missing')
    text = text.replace(
        anchor,
        anchor
        + '    this.sourceListingIdsByIndex = const <String?>[],\n'
        + '    this.videoPosterUrlsByIndex = const <String?>[],\n',
        1,
    )
if 'final List<String?> sourceListingIdsByIndex;' not in text:
    anchor = '  final bool enableVideo;\n'
    if text.count(anchor) != 1:
        raise SystemExit('QuickFilterMedia field anchor missing')
    text = text.replace(
        anchor,
        anchor
        + '  final List<String?> sourceListingIdsByIndex;\n'
        + '  final List<String?> videoPosterUrlsByIndex;\n',
        1,
    )
if 'late List<String?> _poolListingIds;' not in text:
    anchor = '  late List<String> _pool;\n'
    if text.count(anchor) != 1:
        raise SystemExit('QuickFilterMedia pool anchor missing')
    text = text.replace(
        anchor,
        anchor
        + '  late List<String?> _poolListingIds;\n'
        + '  late List<String?> _poolPosterUrls;\n',
        1,
    )

old_update = """    if (!listEquals(oldWidget.sources, widget.sources) ||
        oldWidget.enableVideo != widget.enableVideo) {
"""
new_update = """    if (!listEquals(oldWidget.sources, widget.sources) ||
        !listEquals(
          oldWidget.sourceListingIdsByIndex,
          widget.sourceListingIdsByIndex,
        ) ||
        !listEquals(
          oldWidget.videoPosterUrlsByIndex,
          widget.videoPosterUrlsByIndex,
        ) ||
        oldWidget.enableVideo != widget.enableVideo) {
"""
if new_update not in text:
    if old_update not in text:
        raise SystemExit('QuickFilterMedia didUpdate anchor missing')
    text = text.replace(old_update, new_update, 1)

old_shuffle = """  void _reshuffle(List<String> sources) {
    _pool = List<String>.from(sources);
    if (_pool.length > 2) {
      // Source 0 is the art-directed hero for this category. Keep it stable so
      // the first paint is intentional, then randomize only the secondary media.
      final hero = _pool.removeAt(0);
      _pool.shuffle(
        math.Random(
          DateTime.now().microsecondsSinceEpoch ^ widget.rotateSlot * 7919,
        ),
      );
      _pool.insert(0, hero);
    }
    _index = 0;
"""
new_shuffle = """  void _reshuffle(List<String> sources) {
    final order = List<int>.generate(sources.length, (index) => index);
    if (order.length > 2) {
      final hero = order.removeAt(0);
      order.shuffle(
        math.Random(
          DateTime.now().microsecondsSinceEpoch ^ widget.rotateSlot * 7919,
        ),
      );
      order.insert(0, hero);
    }
    _pool = [for (final index in order) sources[index]];
    _poolListingIds = [
      for (final index in order)
        index < widget.sourceListingIdsByIndex.length
            ? widget.sourceListingIdsByIndex[index]
            : null,
    ];
    _poolPosterUrls = [
      for (final index in order)
        index < widget.videoPosterUrlsByIndex.length
            ? widget.videoPosterUrlsByIndex[index]
            : null,
    ];
    _index = 0;
"""
if new_shuffle not in text:
    if old_shuffle not in text:
        raise SystemExit('QuickFilterMedia reshuffle anchor missing')
    text = text.replace(old_shuffle, new_shuffle, 1)

index_helper = """  String? _listingIdForIndex(int index, String url) {
    if (index >= 0 && index < _poolListingIds.length) {
      final direct = _poolListingIds[index]?.trim();
      if (direct != null && direct.isNotEmpty) return direct;
    }
    return _listingIdForUrl(url);
  }
"""
if index_helper not in text:
    anchor = """  String? _listingIdForUrl(String url) {
    final normalized = url.trim();
    for (final entry in widget.sourceListingIds.entries) {
      if (entry.key.trim() == normalized) return entry.value;
    }
    for (final entry in widget.sourceImageListingIds.entries) {
      if (entry.key.trim() == normalized) return entry.value;
    }
    return null;
  }
"""
    if anchor not in text:
        raise SystemExit('QuickFilterMedia listing helper anchor missing')
    text = text.replace(anchor, anchor + '\n' + index_helper, 1)

# Keep telemetry, handoff, prefetch and open actions on the exact shuffled item.
text = text.replace(
    'listingId: _listingIdForUrl(url),',
    'listingId: _listingIdForIndex(_index % _sources.length, url),',
)
text = text.replace(
    'listingId: _listingIdForUrl(nextUrl),',
    'listingId: _listingIdForIndex(nextIndex, nextUrl),',
)
text = text.replace(
    'final listingId = _listingIdForUrl(current);',
    'final listingId = _listingIdForIndex(_index % _sources.length, current);',
    1,
)
text = text.replace(
    'widget.onOpen?.call(_listingIdForUrl(current));',
    'widget.onOpen?.call(_listingIdForIndex(_index % sources.length, current));',
)

poster_direct = """    if (_index >= 0 && _index < _poolPosterUrls.length) {
      final direct = _poolPosterUrls[_index]?.trim();
      if (direct != null && direct.isNotEmpty) return direct;
    }
"""
if poster_direct not in text:
    anchor = '  String? _posterForVideo(String url) {\n'
    if text.count(anchor) != 1:
        raise SystemExit('QuickFilterMedia poster helper anchor missing')
    text = text.replace(anchor, anchor + poster_direct, 1)

# Older source versions used the inline expression; introduce nextIndex only if
# that old shape is still present.
old_prefetch = """    final nextUrl = sources[(_index + 1) % sources.length].trim();
    if (!_isKnownVideoUrl(nextUrl)) return;
"""
new_prefetch = """    final nextIndex = (_index + 1) % sources.length;
    final nextUrl = sources[nextIndex].trim();
    if (!_isKnownVideoUrl(nextUrl)) return;
"""
if old_prefetch in text:
    text = text.replace(old_prefetch, new_prefetch, 1)

path.write_text(text)
