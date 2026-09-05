from pathlib import Path

ROOT = Path('.')


def read(path: str) -> str:
    return (ROOT / path).read_text()


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'anchor missing: {label}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# 1) Keep fully fetched swipe decks warm for a short TTL and prime the main
#    marketplace categories just after the dashboard paints. A quick-filter tap
#    can then paint from memory instead of waiting for its first RPC.
# ---------------------------------------------------------------------------
p = 'lib/src/features/swipes/presentation/providers/swipe_providers.dart'
s = read(p)
old = """      final user = ref.watch(currentUserProvider);\n      if (user == null) return const <Listing>[];\n      final filters = ref.watch(swipeFilterProvider);\n"""
new = """      final user = ref.watch(currentUserProvider);\n      if (user == null) return const <Listing>[];\n\n      // A dashboard tap should feel like the deck was already waiting behind\n      // the tile. Keep a completed full-deck request alive briefly even when\n      // it was started speculatively by the app-level warmup below. Realtime\n      // invalidation still wins immediately, so this never freezes stale rows.\n      final keepAlive = ref.keepAlive();\n      final ttl = Timer(const Duration(minutes: 2), keepAlive.close);\n      ref.onDispose(ttl.cancel);\n\n      final filters = ref.watch(swipeFilterProvider);\n"""
s = replace_once(s, old, new, 'swipe deck TTL')

old = """  // Avoid five simultaneous full-feed requests during app startup. Property\n  // is the most common first deck, so warm only it after the dashboard paints.\n  unawaited(\n    Future<void>.delayed(const Duration(milliseconds: 450), () async {\n      await ref.read(swipeListingsProvider('property').future);\n    }).catchError((_) {}),\n  );\n"""
new = """  // Prime the main listing decks immediately after the dashboard paints.\n  // Two small batches avoid a startup network spike while still making the\n  // first quick-filter tap feel effectively instant on a normal connection.\n  unawaited(\n    Future<void>.delayed(const Duration(milliseconds: 160), () async {\n      Future<void> warmBatch(List<String> categories) async {\n        await Future.wait<void>(\n          categories.map((category) async {\n            if (ref.read(currentUserProvider)?.id != user.id) return;\n            try {\n              await ref\n                  .read(swipeListingsProvider(category).future)\n                  .timeout(const Duration(seconds: 4));\n            } catch (_) {}\n          }),\n        );\n      }\n\n      await warmBatch(const <String>['property', 'worker', 'yacht']);\n      await Future<void>.delayed(const Duration(milliseconds: 90));\n      await warmBatch(const <String>['motorcycle', 'bicycle', 'services']);\n    }).catchError((_) {}),\n  );\n"""
s = replace_once(s, old, new, 'discovery deck warmup')
write(p, s)


# ---------------------------------------------------------------------------
# 2) Listing photos: use the same high-quality source settings everywhere.
#    2880px / quality 93 preserves substantially more crop/zoom detail than the
#    old 1920px / 86 path without the huge bandwidth cost of pointless 8K files.
# ---------------------------------------------------------------------------
for p in [
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
]:
    s = read(p)
    s = s.replace(
        "imageQuality: 86,\n        maxWidth: 1920,\n        maxHeight: 1920,",
        "imageQuality: 93,\n        maxWidth: 2880,\n        maxHeight: 2880,",
    )
    if 'imageQuality: 86' in s or 'maxWidth: 1920' in s:
        raise SystemExit(f'old listing photo quality remains in {p}')
    write(p, s)

p = 'lib/src/features/add/presentation/providers/edit_listing_provider.dart'
s = read(p)
s = s.replace(
    "imageQuality: 92,\n        maxWidth: 2400,\n        maxHeight: 2400,",
    "imageQuality: 93,\n        maxWidth: 2880,\n        maxHeight: 2880,",
)
write(p, s)


# ---------------------------------------------------------------------------
# 3) New photo objects are immutable unique paths, so a long browser/CDN cache
#    is safe and makes repeat dashboard/deck opens much faster.
# ---------------------------------------------------------------------------
p = 'lib/src/features/swipes/data/repositories/listing_repository.dart'
s = read(p)
old = """                  fileOptions: FileOptions(\n                    contentType: _contentTypeFor(ext),\n                    upsert: true,\n                  ),\n"""
new = """                  fileOptions: FileOptions(\n                    contentType: _contentTypeFor(ext),\n                    cacheControl: '31536000',\n                    upsert: true,\n                  ),\n"""
s = replace_once(s, old, new, 'listing image immutable cache')
write(p, s)


# ---------------------------------------------------------------------------
# 4) Regression guard.
# ---------------------------------------------------------------------------
p = 'test/dashboard_prefetch_photo_quality_guard_test.dart'
write(
    p,
    """import 'dart:io';\n\nimport 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('dashboard decks are prefetched and held briefly for instant taps', () {\n    final source = File(\n      'lib/src/features/swipes/presentation/providers/swipe_providers.dart',\n    ).readAsStringSync();\n\n    expect(source, contains('Duration(minutes: 2)'));\n    expect(\n      source,\n      contains(\"const <String>['property', 'worker', 'yacht']\"),\n    );\n    expect(\n      source,\n      contains(\"const <String>['motorcycle', 'bicycle', 'services']\"),\n    );\n  });\n\n  test('listing photo inputs use HQ source dimensions consistently', () {\n    for (final path in <String>[\n      'lib/src/features/add/presentation/providers/add_listing_provider.dart',\n      'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',\n      'lib/src/features/add/presentation/providers/edit_listing_provider.dart',\n    ]) {\n      final source = File(path).readAsStringSync();\n      expect(source, contains('imageQuality: 93'));\n      expect(source, contains('maxWidth: 2880'));\n      expect(source, contains('maxHeight: 2880'));\n    }\n  });\n\n  test('new listing photos are uploaded with long immutable cache headers', () {\n    final source = File(\n      'lib/src/features/swipes/data/repositories/listing_repository.dart',\n    ).readAsStringSync();\n    expect(source, contains(\"cacheControl: '31536000'\"));\n  });\n}\n""",
)
