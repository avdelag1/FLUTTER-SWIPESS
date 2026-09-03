from pathlib import Path


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing patch target: {label}')
    return text.replace(old, new, 1)


# The quick-filter card is already painted from the lightweight preview
# provider. Reuse that exact in-memory Listing when opening the full deck so
# active deck filters can never make the tapped card disappear on frame one.
p = 'lib/src/features/swipes/presentation/utils/open_swipe_deck.dart'
s = read(p)
s = replace_once(
    s,
    """  // Paint the deck from warmed cache on the first frame after the tap.\n  unawaited(container.read(swipeListingsProvider(categoryId).future));\n  _warmDeckHeroImages(context, container, categoryId);\n\n  final route = PageRouteBuilder<T>(\n""",
    """  // Paint the deck from warmed cache on the first frame after the tap.\n  // Also capture the exact dashboard preview object synchronously. The light\n  // preview feed is intentionally broader than a user's full deck filters, so\n  // an ID-only handoff could otherwise fall back to card #1 when the tapped\n  // item is outside an active price/rent/sale filter.\n  Listing? exactPreviewListing;\n  final exactId = preferredListingId?.trim();\n  if (exactId != null && exactId.isNotEmpty) {\n    final preview = container.read(\n      quickFilterPreviewListingsProvider(categoryId),\n    ).value;\n    if (preview != null) {\n      for (final listing in preview) {\n        if (listing.id == exactId) {\n          exactPreviewListing = listing;\n          break;\n        }\n      }\n    }\n  }\n\n  unawaited(container.read(swipeListingsProvider(categoryId).future));\n  _warmDeckHeroImages(context, container, categoryId);\n\n  final route = PageRouteBuilder<T>(\n""",
    'capture exact preview listing',
)
s = replace_once(
    s,
    """      initialListingId: preferredListingId,\n    ),\n""",
    """      initialListingId: preferredListingId,\n      initialListing: exactPreviewListing,\n    ),\n""",
    'pass exact preview listing',
)
write(p, s)


p = 'lib/src/features/swipes/presentation/screens/client_swipe_container.dart'
s = read(p)
s = replace_once(
    s,
    """import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';\n""",
    """import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';\nimport 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';\n""",
    'listing repository import',
)
s = replace_once(
    s,
    """    required this.categoryTitle,\n    this.initialListingId,\n  });\n\n  final String categoryId;\n  final String categoryTitle;\n  final String? initialListingId;\n""",
    """    required this.categoryTitle,\n    this.initialListingId,\n    this.initialListing,\n  });\n\n  final String categoryId;\n  final String categoryTitle;\n  final String? initialListingId;\n  final Listing? initialListing;\n""",
    'initial listing constructor',
)

old = """  void _ensureDeck(List<Listing> source) {\n    final fingerprint = _deckFingerprint(source);\n    if (_deck != null && _deckSourceFingerprint == fingerprint) return;\n\n    final currentVisibleId = _deck != null && _deck!.isNotEmpty\n        ? _deck!.first.id\n        : null;\n    final explicitId = widget.initialListingId?.trim();\n    final hasExplicitId = explicitId != null && explicitId.isNotEmpty;\n    final pendingId =\n        currentVisibleId ??\n        (hasExplicitId ? explicitId : SwipeDeckMediaHandoff.pendingListingId);\n    final pendingCategory = hasExplicitId || currentVisibleId != null\n        ? _categoryId\n        : SwipeDeckMediaHandoff.pendingCategoryId;\n\n    final next = List<Listing>.from(source);\n    if (pendingId != null &&\n        (pendingCategory == null || pendingCategory == _categoryId)) {\n      _prioritizeListing(next, pendingId);\n    }\n\n    _deck = next;\n    _deckSourceFingerprint = fingerprint;\n  }\n"""
new = """  void _ensureDeck(List<Listing> source) {\n    final fingerprint = _deckFingerprint(source);\n    if (_deck != null && _deckSourceFingerprint == fingerprint) return;\n\n    final currentVisible = _deck != null && _deck!.isNotEmpty\n        ? _deck!.first\n        : null;\n    final explicitId = widget.initialListingId?.trim();\n    final hasExplicitId = explicitId != null && explicitId.isNotEmpty;\n    final pendingId = hasExplicitId\n        ? explicitId\n        : SwipeDeckMediaHandoff.pendingListingId;\n    final pendingCategory = hasExplicitId\n        ? _categoryId\n        : SwipeDeckMediaHandoff.pendingCategoryId;\n\n    final next = List<Listing>.from(source);\n\n    // On a provider/realtime refresh, keep the card the user is actually\n    // looking at in place. If broad dashboard discovery showed a card that a\n    // narrower deck filter omits, preserve the exact visible object rather\n    // than snapping to an unrelated card.\n    if (currentVisible != null) {\n      final target = next.indexWhere((listing) => listing.id == currentVisible.id);\n      if (target > 0) {\n        final freshVisible = next.removeAt(target);\n        next.insert(0, freshVisible);\n      } else if (target < 0) {\n        next.insert(0, currentVisible);\n      }\n    } else if (widget.initialListing != null) {\n      final exact = widget.initialListing!;\n      next.removeWhere((listing) => listing.id == exact.id);\n      next.insert(0, exact);\n    } else if (pendingId != null &&\n        (pendingCategory == null || pendingCategory == _categoryId)) {\n      _prioritizeListing(next, pendingId);\n    }\n\n    _deck = next;\n    _deckSourceFingerprint = fingerprint;\n  }\n"""
s = replace_once(s, old, new, 'exact deck initialization and reconciliation')

old = """      ref.invalidate(swipeListingsProvider(_categoryId));\n      ref.invalidate(quickFilterPreviewListingsProvider(_categoryId));\n      final fresh = await ref.read(swipeListingsProvider(_categoryId).future);\n      if (!mounted) return;\n\n      setState(() {\n        _deck = _prioritizeListing(List<Listing>.from(fresh), visibleId);\n        _deckSourceFingerprint = _deckFingerprint(fresh);\n        _undoable = null;\n      });\n"""
new = """      ref.invalidate(swipeListingsProvider(_categoryId));\n      ref.invalidate(quickFilterPreviewListingsProvider(_categoryId));\n      final fresh = await ref.read(swipeListingsProvider(_categoryId).future);\n      if (!mounted) return;\n\n      final next = List<Listing>.from(fresh);\n      if (visibleId != null &&\n          next.every((listing) => listing.id != visibleId)) {\n        try {\n          final exact = await ref\n              .read(listingRepositoryProvider)\n              .fetchById(visibleId);\n          if (exact != null) next.insert(0, exact);\n        } catch (_) {\n          final current = _deck != null && _deck!.isNotEmpty\n              ? _deck!.first\n              : null;\n          if (current != null && current.id == visibleId) {\n            next.insert(0, current);\n          }\n        }\n      } else {\n        _prioritizeListing(next, visibleId);\n      }\n      if (!mounted) return;\n\n      setState(() {\n        _deck = next;\n        _deckSourceFingerprint = _deckFingerprint(fresh);\n        _undoable = null;\n      });\n"""
s = replace_once(s, old, new, 'refresh exact visible listing')
write(p, s)

print('Guaranteed exact quick-filter listing handoff and refresh preservation.')
