from pathlib import Path
import re


def load(path):
    return Path(path).read_text()


def save(path, text):
    Path(path).write_text(text)


def replace_one(text, old, new, label):
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    return text.replace(old, new, 1)


def regex_one(text, pattern, replacement, label, already=None):
    if already and already in text:
        return text
    next_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'{label}: regex matched {count}')
    return next_text


# Safari/PWA exporter: keep the source element in the compositor.
path = 'lib/src/features/camera/data/video_recut_v3_html.dart'
text = load(path)
if "..left = '-10000px'" in text:
    text = text.replace("..left = '-10000px'", "..left = '0'", 1)
if "..width = '4px'" in text:
    text = text.replace("..width = '4px'", "..width = '2px'", 1)
if "..height = '4px'" in text:
    text = text.replace("..height = '4px'", "..height = '2px'", 1)
if "setProperty('will-change', 'transform')" not in text:
    text = regex_one(
        text,
        r"(video\.style\s*\n\s*\.\.position = 'fixed'.*?\.\.pointerEvents = 'none';)",
        r"\1\n    video.style\n      ..setProperty('z-index', '2147483647')\n      ..setProperty('transform', 'translateZ(0)')\n      ..setProperty('will-change', 'transform');\n    video.setAttribute('playsinline', 'true');\n    video.setAttribute('webkit-playsinline', 'true');",
        'browser compositor flags',
    )
save(path, text)

# Vercel worker: normalize progressive delivery to constant 30fps.
path = 'api/video-transcode.js'
text = load(path)
text = replace_one(
    text,
    "'scale=1280:1280:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1',\n    '-c:v',",
    "'scale=1280:1280:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1,fps=30',\n    '-r',\n    '30',\n    '-c:v',",
    'CFR delivery output',
)
save(path, text)

# Feed recency is the row creation action, never a later edit.
path = 'lib/src/features/swipes/presentation/providers/swipe_providers.dart'
text = load(path)
if 'final aDate = a.createdAt;' not in text:
    text = replace_one(
        text,
        'final aDate = a.updatedAt ?? a.createdAt;',
        'final aDate = a.createdAt;',
        'created_at sort A',
    )
if 'final bDate = b.createdAt;' not in text:
    text = replace_one(
        text,
        'final bDate = b.updatedAt ?? b.createdAt;',
        'final bDate = b.createdAt;',
        'created_at sort B',
    )
text = text.replace(
    '  // A real edit is a fresh marketplace signal. Normal category feeds should\n'
    '  // surface the most recently updated item first, just like a newly refreshed\n'
    '  // post. Keep Recommended untouched so its quality/personalization ranking is\n'
    '  // never replaced by simple recency.\n',
    '  // Keep publication age tied to the immutable listing row. Edits may\n'
    '  // refresh content via updated_at, but they must never become a new post.\n',
    1,
)
save(path, text)

# Repository guard: even a future edit caller cannot overwrite created_at.
path = 'lib/src/features/swipes/data/repositories/listing_repository.dart'
text = load(path)
if "..remove('created_at')" not in text:
    text = regex_one(
        text,
        r"(Future<Listing> updateListing\(\s*String listingId,\s*Map<String, dynamic> payload,\s*\) \{\s*)final safe = Map<String, dynamic>\.from\(payload\)\.\.remove\('user_id'\);",
        r"\1final safe = Map<String, dynamic>.from(payload)\n      ..remove('user_id')\n      ..remove('created_at');",
        'protect created_at on edit',
    )
save(path, text)

# Local create/edit paths refresh dashboard quick-filter providers immediately.
for path in [
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    'lib/src/features/add/presentation/providers/edit_listing_provider.dart',
]:
    text = load(path)
    if 'ref.invalidate(quickFilterPreviewListingsProvider);' not in text:
        text = regex_one(
            text,
            r"(\s+ref\.invalidate\(swipeListingsProvider\);)",
            r"\1\n      ref.invalidate(quickFilterPreviewListingsProvider);",
            f'quick-filter invalidation {path}',
        )
    save(path, text)

# Generic quick-filter player: identity/poster follow listing row ID by index.
path = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
text = load(path)
if 'this.sourceListingIdsByIndex = const <String?>[],' not in text:
    text = replace_one(
        text,
        '    this.enableVideo = true,\n',
        '    this.enableVideo = true,\n'
        '    this.sourceListingIdsByIndex = const <String?>[],\n'
        '    this.videoPosterUrlsByIndex = const <String?>[],\n',
        'quick-filter constructor identity arrays',
    )
if 'final List<String?> sourceListingIdsByIndex;' not in text:
    text = replace_one(
        text,
        '  final bool enableVideo;\n',
        '  final bool enableVideo;\n'
        '  final List<String?> sourceListingIdsByIndex;\n'
        '  final List<String?> videoPosterUrlsByIndex;\n',
        'quick-filter identity fields',
    )
if 'late List<String?> _poolListingIds;' not in text:
    text = replace_one(
        text,
        '  late List<String> _pool;\n',
        '  late List<String> _pool;\n'
        '  late List<String?> _poolListingIds;\n'
        '  late List<String?> _poolPosterUrls;\n',
        'quick-filter aligned pool fields',
    )
if 'oldWidget.sourceListingIdsByIndex' not in text:
    text = regex_one(
        text,
        r"if \(!listEquals\(oldWidget\.sources, widget\.sources\) \|\|\s*oldWidget\.enableVideo != widget\.enableVideo\) \{",
        "if (!listEquals(oldWidget.sources, widget.sources) ||\n"
        "        !listEquals(oldWidget.sourceListingIdsByIndex, widget.sourceListingIdsByIndex) ||\n"
        "        !listEquals(oldWidget.videoPosterUrlsByIndex, widget.videoPosterUrlsByIndex) ||\n"
        "        oldWidget.enableVideo != widget.enableVideo) {",
        'quick-filter didUpdate identity',
    )
if 'final order = List<int>.generate(sources.length' not in text:
    text = regex_one(
        text,
        r"  void _reshuffle\(List<String> sources\) \{.*?\n  \}\n\n  void _beginTelemetryFor",
        """  void _reshuffle(List<String> sources) {
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
    _webPointerShieldHold = false;
  }

  void _beginTelemetryFor""",
        'quick-filter paired shuffle',
    )
if 'String? _listingIdForIndex(int index, String url)' not in text:
    text = regex_one(
        text,
        r"(  String\? _listingIdForUrl\(String url\) \{.*?\n  \}\n)",
        r"\1\n  String? _listingIdForIndex(int index, String url) {\n    if (index >= 0 && index < _poolListingIds.length) {\n      final direct = _poolListingIds[index]?.trim();\n      if (direct != null && direct.isNotEmpty) return direct;\n    }\n    return _listingIdForUrl(url);\n  }\n",
        'quick-filter listing ID helper',
    )
text = text.replace(
    'listingId: _listingIdForUrl(url),',
    'listingId: _listingIdForIndex(_index % _sources.length, url),',
    1,
)
if 'final nextIndex = (_index + 1) % sources.length;' not in text:
    text = replace_one(
        text,
        '    final nextUrl = sources[(_index + 1) % sources.length].trim();\n',
        '    final nextIndex = (_index + 1) % sources.length;\n'
        '    final nextUrl = sources[nextIndex].trim();\n',
        'quick-filter next index',
    )
text = text.replace(
    'listingId: _listingIdForUrl(nextUrl),',
    'listingId: _listingIdForIndex(nextIndex, nextUrl),',
    1,
)
text = text.replace(
    'final listingId = _listingIdForUrl(current);',
    'final listingId = _listingIdForIndex(_index % _sources.length, current);',
    1,
)
if 'final direct = _poolPosterUrls[_index]?.trim();' not in text:
    text = replace_one(
        text,
        '  String? _posterForVideo(String url) {\n',
        '  String? _posterForVideo(String url) {\n'
        '    if (_index >= 0 && _index < _poolPosterUrls.length) {\n'
        '      final direct = _poolPosterUrls[_index]?.trim();\n'
        '      if (direct != null && direct.isNotEmpty) return direct;\n'
        '    }\n',
        'quick-filter aligned poster',
    )
old_open = 'widget.onOpen?.call(_listingIdForUrl(current));'
if old_open in text:
    count = text.count(old_open)
    if count != 3:
        raise SystemExit(f'quick-filter open identity: expected 3 calls, found {count}')
    text = text.replace(
        old_open,
        'widget.onOpen?.call(_listingIdForIndex(_index % sources.length, current));',
    )
save(path, text)

# Dashboard cards: restore video on all real listing quick filters and pass IDs.
path = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
text = load(path)
if 'enableVideo: isListingPreviewQuickFilter,' not in text:
    text = replace_one(
        text,
        '          enableVideo: false,\n',
        '          enableVideo: isListingPreviewQuickFilter,\n',
        'enable listing quick-filter video',
    )
    text = text.replace(
        '          // During the Properties canary, every other listing category remains\n'
        '          // a static poster so hidden decoders cannot contaminate the test.\n',
        '          // Listing categories share the processed, bounded video preview path.\n',
        1,
    )
if 'sourceListingIdsByIndex: listingPreviewListingIds,' not in text:
    text = replace_one(
        text,
        '          sourceListingIds: sourceListingIds,\n',
        '          sourceListingIdsByIndex: listingPreviewListingIds,\n'
        '          videoPosterUrlsByIndex: listingPreviewPosterUrls,\n'
        '          sourceListingIds: sourceListingIds,\n',
        'bento indexed identity args',
    )
if 'this.sourceListingIdsByIndex = const <String?>[],' not in text:
    text = replace_one(
        text,
        '    this.slotCount = 1,\n',
        '    this.slotCount = 1,\n'
        '    this.sourceListingIdsByIndex = const <String?>[],\n'
        '    this.videoPosterUrlsByIndex = const <String?>[],\n',
        'bento indexed constructor',
    )
if 'final List<String?> sourceListingIdsByIndex;' not in text:
    text = replace_one(
        text,
        '  final int slotCount;\n',
        '  final int slotCount;\n'
        '  final List<String?> sourceListingIdsByIndex;\n'
        '  final List<String?> videoPosterUrlsByIndex;\n',
        'bento indexed fields',
    )
if 'sourceListingIdsByIndex: widget.sourceListingIdsByIndex,' not in text:
    text = replace_one(
        text,
        '                  showMute: widget.enableVideo,\n',
        '                  showMute: widget.enableVideo,\n'
        '                  sourceListingIdsByIndex: widget.sourceListingIdsByIndex,\n'
        '                  videoPosterUrlsByIndex: widget.videoPosterUrlsByIndex,\n',
        'bento player indexed args',
    )
save(path, text)

print('final listing video/timestamp patch applied')
