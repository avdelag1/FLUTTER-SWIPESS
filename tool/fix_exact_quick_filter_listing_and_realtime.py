from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch target: {label}')
    return text.replace(old, new, 1)


# 1) Quick-filter media must report the exact listing represented by the
# currently visible photo OR video when the user opens the card.
p = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
s = read(p)
s = replace_once(
    s,
    '  final VoidCallback? onOpen;\n',
    '  final ValueChanged<String?>? onOpen;\n',
    'quick-filter open callback type',
)
s = replace_once(
    s,
    '              widget.onOpen?.call();\n',
    '              widget.onOpen?.call(_listingIdForUrl(current));\n',
    'quick-filter exact listing tap',
)
write(p, s)

# 2) Dashboard preview maps every real listing source (photo or video) to its
# listing id, then forwards that id through the category opener.
p = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
s = read(p)
s = replace_once(
    s,
    '  void _openCategory(String id, String title) {\n',
    '  void _openCategory(\n    String id,\n    String title,\n    String? preferredListingId,\n  ) {\n',
    'dashboard category opener signature',
)
s = replace_once(
    s,
    '        openClientSwipeDeck(context, categoryId: id, categoryTitle: title);\n',
    """        openClientSwipeDeck(\n          context,\n          categoryId: id,\n          categoryTitle: title,\n          preferredListingId: preferredListingId,\n        );\n""",
    'dashboard exact listing deck open',
)
# _BentoColumn and _BentoTile both carry this callback.
old_type = '  final void Function(String id, String title) onOpen;\n'
new_type = (
    '  final void Function(\n'
    '    String id,\n'
    '    String title,\n'
    '    String? preferredListingId,\n'
    '  ) onOpen;\n'
)
if s.count(old_type) != 2:
    raise SystemExit('missing patch target: dashboard bento callback types')
s = s.replace(old_type, new_type, 2)
s = replace_once(
    s,
    """      listingPreviewMedia.add(source);\n      if (video.isNotEmpty) {\n        sourceListingIds[video] = listing.id;\n        if (image.isNotEmpty) videoPosterUrls[video] = image;\n      }\n""",
    """      listingPreviewMedia.add(source);\n      sourceListingIds[source] = listing.id;\n      if (video.isNotEmpty && image.isNotEmpty) {\n        videoPosterUrls[video] = image;\n      }\n""",
    'map photo and video source to listing',
)
s = replace_once(
    s,
    '                        onOpen(item.id, item.title);\n',
    '                        onOpen(item.id, item.title, null);\n',
    'events category callback',
)
s = replace_once(
    s,
    """          onTap: () {\n            ref.read(accessedCategoriesProvider).markAccessed(item.id);\n            onOpen(item.id, item.title);\n          },\n""",
    """          onTap: (listingId) {\n            ref.read(accessedCategoriesProvider).markAccessed(item.id);\n            onOpen(item.id, item.title, listingId);\n          },\n""",
    'listing quick-filter callback',
)
s = replace_once(
    s,
    '  final VoidCallback onTap;\n',
    '  final ValueChanged<String?> onTap;\n',
    'bento card callback type',
)
write(p, s)

# 3) Deck opener accepts a target listing id. Video handoff still works exactly
# as before, while photo taps can now request the matching listing too.
p = 'lib/src/features/swipes/presentation/utils/open_swipe_deck.dart'
s = read(p)
s = replace_once(
    s,
    """  required String categoryTitle,\n  bool replace = false,\n}) async {\n""",
    """  required String categoryTitle,\n  String? preferredListingId,\n  bool replace = false,\n}) async {\n""",
    'deck preferred listing parameter',
)
s = replace_once(
    s,
    """    pageBuilder: (_, __, ___) => ClientSwipeContainer(\n      categoryId: categoryId,\n      categoryTitle: categoryTitle,\n    ),\n""",
    """    pageBuilder: (_, __, ___) => ClientSwipeContainer(\n      categoryId: categoryId,\n      categoryTitle: categoryTitle,\n      initialListingId: preferredListingId,\n    ),\n""",
    'deck container exact listing target',
)
write(p, s)

# 4) Put the exact previewed listing at deck index zero before first paint.
p = 'lib/src/features/swipes/presentation/screens/client_swipe_container.dart'
s = read(p)
s = replace_once(
    s,
    """    required this.categoryTitle,\n  });\n\n  final String categoryId;\n  final String categoryTitle;\n""",
    """    required this.categoryTitle,\n    this.initialListingId,\n  });\n\n  final String categoryId;\n  final String categoryTitle;\n  final String? initialListingId;\n""",
    'client deck initial listing field',
)
s = replace_once(
    s,
    """    final next = List<Listing>.from(source);\n    final pendingId = SwipeDeckMediaHandoff.pendingListingId;\n    final pendingCategory = SwipeDeckMediaHandoff.pendingCategoryId;\n""",
    """    final next = List<Listing>.from(source);\n    final explicitId = widget.initialListingId?.trim();\n    final hasExplicitId = explicitId != null && explicitId.isNotEmpty;\n    final pendingId = hasExplicitId\n        ? explicitId\n        : SwipeDeckMediaHandoff.pendingListingId;\n    final pendingCategory = hasExplicitId\n        ? _categoryId\n        : SwipeDeckMediaHandoff.pendingCategoryId;\n""",
    'client deck prioritize exact previewed listing',
)
write(p, s)

# 5) Other signed-in users should not keep a stale FutureProvider forever after
# someone publishes or edits a listing. Realtime invalidates category decks and
# quick-filter previews immediately; the next provider read fetches fresh data.
p = 'lib/src/features/swipes/presentation/providers/swipe_providers.dart'
s = read(p)
anchor = """  if (user == null) return;\n\n  // Avoid five simultaneous full-feed requests during app startup. Property\n"""
replacement = """  if (user == null) return;\n\n  final client = Supabase.instance.client;\n  final realtime = client\n      .channel('listing-discovery-${user.id}')\n      .onPostgresChanges(\n        event: PostgresChangeEvent.all,\n        schema: 'public',\n        table: 'listings',\n        callback: (_) {\n          for (final category in const <String>[\n            'property',\n            'services',\n            'worker',\n            'yacht',\n            'motorcycle',\n            'bicycle',\n            'recommended',\n            'all',\n          ]) {\n            ref.invalidate(swipeListingsProvider(category));\n          }\n          for (final category in const <String>[\n            'property',\n            'services',\n            'yacht',\n            'motorcycle',\n            'bicycle',\n          ]) {\n            ref.invalidate(quickFilterPreviewListingsProvider(category));\n          }\n        },\n      )\n      .subscribe();\n  ref.onDispose(() {\n    unawaited(client.removeChannel(realtime));\n  });\n\n  // Avoid five simultaneous full-feed requests during app startup. Property\n"""
s = replace_once(s, anchor, replacement, 'signed-in listing realtime refresh')
write(p, s)
