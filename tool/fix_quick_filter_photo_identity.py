from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch target: {label}')
    return text.replace(old, new, 1)


# Keep video identity and still-photo identity separate. sourceListingIds is
# intentionally video-only because QuickFilterMedia uses its keys to recognize
# extensionless CDN video URLs.
p = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
s = read(p)
s = replace_once(
    s,
    """    final sourceListingIds = <String, String>{};\n    final videoPosterUrls = <String, String>{};\n""",
    """    final sourceListingIds = <String, String>{};\n    final sourceImageListingIds = <String, String>{};\n    final videoPosterUrls = <String, String>{};\n""",
    'dashboard photo identity map',
)
s = replace_once(
    s,
    """      listingPreviewMedia.add(source);\n      sourceListingIds[source] = listing.id;\n      if (video.isNotEmpty && image.isNotEmpty) {\n        videoPosterUrls[video] = image;\n      }\n""",
    """      listingPreviewMedia.add(source);\n      if (video.isNotEmpty) {\n        sourceListingIds[video] = listing.id;\n        if (image.isNotEmpty) videoPosterUrls[video] = image;\n      } else {\n        sourceImageListingIds[source] = listing.id;\n      }\n""",
    'separate video and photo listing ids',
)
s = replace_once(
    s,
    """          sourceListingIds: sourceListingIds,\n          videoPosterUrls: videoPosterUrls,\n""",
    """          sourceListingIds: sourceListingIds,\n          sourceImageListingIds: sourceImageListingIds,\n          videoPosterUrls: videoPosterUrls,\n""",
    'pass photo listing ids to card',
)
s = replace_once(
    s,
    """    this.sourceListingIds = const <String, String>{},\n    this.videoPosterUrls = const <String, String>{},\n""",
    """    this.sourceListingIds = const <String, String>{},\n    this.sourceImageListingIds = const <String, String>{},\n    this.videoPosterUrls = const <String, String>{},\n""",
    'card photo identity constructor',
)
s = replace_once(
    s,
    """  final Map<String, String> sourceListingIds;\n  final Map<String, String> videoPosterUrls;\n""",
    """  final Map<String, String> sourceListingIds;\n  final Map<String, String> sourceImageListingIds;\n  final Map<String, String> videoPosterUrls;\n""",
    'card photo identity field',
)
s = replace_once(
    s,
    """                  sourceListingIds: widget.sourceListingIds,\n                  videoPosterUrls: widget.videoPosterUrls,\n""",
    """                  sourceListingIds: widget.sourceListingIds,\n                  sourceImageListingIds: widget.sourceImageListingIds,\n                  videoPosterUrls: widget.videoPosterUrls,\n""",
    'pass photo listing ids to media',
)
write(p, s)

p = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
s = read(p)
s = replace_once(
    s,
    """    this.sourceListingIds = const <String, String>{},\n    this.videoPosterUrls = const <String, String>{},\n""",
    """    this.sourceListingIds = const <String, String>{},\n    this.sourceImageListingIds = const <String, String>{},\n    this.videoPosterUrls = const <String, String>{},\n""",
    'media photo identity constructor',
)
s = replace_once(
    s,
    """  final Map<String, String> sourceListingIds;\n  final Map<String, String> videoPosterUrls;\n""",
    """  final Map<String, String> sourceListingIds;\n  final Map<String, String> sourceImageListingIds;\n  final Map<String, String> videoPosterUrls;\n""",
    'media photo identity field',
)
s = replace_once(
    s,
    """  String? _listingIdForUrl(String url) {\n    final normalized = url.trim();\n    for (final entry in widget.sourceListingIds.entries) {\n      if (entry.key.trim() == normalized) return entry.value;\n    }\n    return null;\n  }\n""",
    """  String? _listingIdForUrl(String url) {\n    final normalized = url.trim();\n    for (final entry in widget.sourceListingIds.entries) {\n      if (entry.key.trim() == normalized) return entry.value;\n    }\n    for (final entry in widget.sourceImageListingIds.entries) {\n      if (entry.key.trim() == normalized) return entry.value;\n    }\n    return null;\n  }\n""",
    'resolve photo listing identity',
)
write(p, s)
